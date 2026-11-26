import AVFoundation
import Foundation
import Observation

public enum TimeFormatting {
    public static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

/// Native macOS audio player powered by AVAudioEngine and AVAudioUnitTimePitch.
/// Changes playback speed smoothly while keeping pitch locked at 0 cents.
@MainActor
@Observable
public final class AudioPlayerEngine {
    public static let minRate: Float = 0.25
    public static let maxRate: Float = 2.0
    public static let speedPresets: [Float] = [0.25, 0.5, 0.65, 0.75, 0.85, 0.9, 1.0, 1.5, 2.0]

    public private(set) var fileURL: URL?
    public private(set) var fileName: String = ""
    public private(set) var duration: TimeInterval = 0
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var isPlaying: Bool = false
    public private(set) var waveformSamples: [Float] = []
    public private(set) var isLoadingWaveform: Bool = false
    public private(set) var errorMessage: String?

    public var playbackRate: Float = 1.0 {
        didSet {
            let clamped = Self.clampRate(playbackRate)
            if playbackRate != clamped {
                playbackRate = clamped
                return
            }
            timePitch.rate = clamped
            // Always guarantee pitch remains locked to 0 cents (original pitch).
            timePitch.pitch = 0.0
        }
    }

    public var volume: Float = 0.85 {
        didSet {
            let clamped = min(1.0, max(0.0, volume))
            if volume != clamped {
                volume = clamped
                return
            }
            applyVolume()
        }
    }

    public var isMuted: Bool = false {
        didSet {
            applyVolume()
        }
    }

    public var loopStart: TimeInterval?
    public var loopEnd: TimeInterval?
    public var isLoopEnabled: Bool = false

    /// Current pitch shift in cents (always 0.0 for pitch-preserving playback).
    public var pitchCents: Float {
        timePitch.pitch
    }

    public var hasFileLoaded: Bool {
        audioFile != nil
    }

    public var hasValidLoop: Bool {
        guard let start = loopStart, let end = loopEnd else { return false }
        return end - start >= 0.25
    }

    // MARK: - Private AVAudioEngine state

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44_100
    private var totalFrames: AVAudioFramePosition = 0
    private var seekFrame: AVAudioFramePosition = 0
    private var needsReschedule: Bool = true
    private var playbackGeneration: UInt64 = 0

    private var progressTimer: Timer?
    private var waveformTask: Task<Void, Never>?

    public init() {
        engine.attach(playerNode)
        engine.attach(timePitch)

        timePitch.rate = playbackRate
        timePitch.pitch = 0.0
        timePitch.overlap = 12.0

        engine.connect(playerNode, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
        applyVolume()
    }

    public static func clampRate(_ rate: Float) -> Float {
        min(maxRate, max(minRate, rate))
    }

    /// Maps a playback rate to a piecewise-linear slider position in `0...(speedPresets.count - 1)`
    /// so each preset sits at its exact integer index directly above its preset button.
    public static func sliderPosition(forRate rate: Float) -> Double {
        let presets = speedPresets
        guard presets.count >= 2 else { return 0 }
        let clamped = clampRate(rate)

        if clamped <= presets[0] { return 0 }
        if clamped >= presets[presets.count - 1] { return Double(presets.count - 1) }

        for i in 0..<(presets.count - 1) {
            let low = presets[i]
            let high = presets[i + 1]
            if clamped >= low && clamped <= high {
                let fraction = Double(clamped - low) / Double(high - low)
                return Double(i) + fraction
            }
        }
        return Double(presets.count - 1)
    }

    /// Inverse of `sliderPosition(forRate:)`: maps a slider position in `0...(speedPresets.count - 1)`
    /// back to a playback rate (rounded to 0.01 increments).
    public static func rate(forSliderPosition position: Double) -> Float {
        let presets = speedPresets
        guard presets.count >= 2 else { return 1.0 }

        let maxIndex = Double(presets.count - 1)
        let clampedPos = min(maxIndex, max(0, position))
        let lowerIndex = min(presets.count - 2, Int(floor(clampedPos)))
        let fraction = clampedPos - Double(lowerIndex)

        let low = Double(presets[lowerIndex])
        let high = Double(presets[lowerIndex + 1])
        let rawRate = low + fraction * (high - low)
        let rounded = Float((rawRate * 100).rounded() / 100)
        return clampRate(rounded)
    }

    public func loadFile(url: URL) {
        errorMessage = nil
        stopPlaybackInternal(resetPosition: true)
        waveformTask?.cancel()

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frames = file.length
            guard frames > 0, format.sampleRate > 0 else {
                errorMessage = "The selected audio file is empty."
                return
            }

            if engine.isRunning {
                engine.stop()
            }

            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitch)
            engine.connect(playerNode, to: timePitch, format: format)
            engine.connect(timePitch, to: engine.mainMixerNode, format: format)

            timePitch.rate = playbackRate
            timePitch.pitch = 0.0
            timePitch.overlap = 12.0
            applyVolume()

            engine.prepare()

            audioFile = file
            fileURL = url
            fileName = url.lastPathComponent
            sampleRate = format.sampleRate
            totalFrames = frames
            duration = Double(frames) / format.sampleRate
            seekFrame = 0
            currentTime = 0
            needsReschedule = true
            clearLoop()

            waveformSamples = []
            isLoadingWaveform = true
            waveformTask = Task { [weak self] in
                do {
                    let samples = try await WaveformExtractor.extractSamples(from: url, sampleCount: 120)
                    guard !Task.isCancelled else { return }
                    self?.waveformSamples = samples
                    self?.isLoadingWaveform = false
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.isLoadingWaveform = false
                }
            }
        } catch {
            errorMessage = "Could not open audio file: \(error.localizedDescription)"
        }
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard audioFile != nil else { return }
        errorMessage = nil

        // If at the end of the track, restart from beginning (or loop start).
        if seekFrame >= totalFrames - 1 {
            if isLoopEnabled, let start = loopStart, hasValidLoop {
                seekFrame = frame(for: start)
                currentTime = start
            } else {
                seekFrame = 0
                currentTime = 0
            }
            needsReschedule = true
        }

        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
            return
        }

        if needsReschedule {
            scheduleFromSeekFrame()
        }

        playerNode.play()
        isPlaying = true
        startProgressTimer()
    }

    public func pause() {
        guard isPlaying else { return }
        updateCurrentTimeFromNode()
        seekFrame = frame(for: currentTime)
        playerNode.pause()
        isPlaying = false
        stopProgressTimer()
    }

    public func stop() {
        stopPlaybackInternal(resetPosition: true)
    }

    public func seek(to time: TimeInterval) {
        guard audioFile != nil else { return }
        let clampedTime = min(max(0, time), duration)
        let targetFrame = frame(for: clampedTime)
        let wasPlaying = isPlaying

        playbackGeneration &+= 1
        playerNode.stop()

        seekFrame = targetFrame
        currentTime = clampedTime
        needsReschedule = true

        if wasPlaying {
            do {
                if !engine.isRunning {
                    try engine.start()
                }
                scheduleFromSeekFrame()
                playerNode.play()
                isPlaying = true
                startProgressTimer()
            } catch {
                isPlaying = false
                stopProgressTimer()
                errorMessage = "Audio engine failed to resume: \(error.localizedDescription)"
            }
        }
    }

    public func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    public func adjustRate(by delta: Float) {
        let rounded = ((playbackRate + delta) * 100).rounded() / 100
        playbackRate = Self.clampRate(rounded)
    }

    public func resetRate() {
        playbackRate = 1.0
    }

    public func setLoopStartAtCurrentTime() {
        guard hasFileLoaded else { return }
        loopStart = currentTime
        if let end = loopEnd, end <= currentTime {
            loopEnd = nil
            isLoopEnabled = false
        } else if hasValidLoop {
            isLoopEnabled = true
        }
    }

    public func setLoopEndAtCurrentTime() {
        guard hasFileLoaded else { return }
        if let start = loopStart, currentTime > start + 0.25 {
            loopEnd = currentTime
            isLoopEnabled = true
        } else {
            loopStart = 0
            loopEnd = max(0.25, currentTime)
            isLoopEnabled = hasValidLoop
        }
    }

    public func clearLoop() {
        loopStart = nil
        loopEnd = nil
        isLoopEnabled = false
    }

    // MARK: - Private helpers

    private func applyVolume() {
        engine.mainMixerNode.outputVolume = isMuted ? 0.0 : volume
    }

    private func frame(for time: TimeInterval) -> AVAudioFramePosition {
        let raw = AVAudioFramePosition((time * sampleRate).rounded())
        return min(max(0, raw), totalFrames)
    }

    private func scheduleFromSeekFrame() {
        guard let file = audioFile else { return }
        let remaining = totalFrames - seekFrame
        guard remaining > 0 else { return }

        let generation = playbackGeneration &+ 1
        playbackGeneration = generation
        needsReschedule = false

        let frameCount = AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max)))
        playerNode.scheduleSegment(
            file,
            startingFrame: seekFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSegmentCompletion(generation: generation)
            }
        }
    }

    private func handleSegmentCompletion(generation: UInt64) {
        guard generation == playbackGeneration else { return }

        if isLoopEnabled, let start = loopStart, hasValidLoop {
            seek(to: start)
            if !isPlaying {
                play()
            }
            return
        }

        isPlaying = false
        stopProgressTimer()
        currentTime = duration
        seekFrame = totalFrames
        needsReschedule = true
    }

    private func stopPlaybackInternal(resetPosition: Bool) {
        playbackGeneration &+= 1
        playerNode.stop()
        isPlaying = false
        stopProgressTimer()
        needsReschedule = true
        if resetPosition {
            seekFrame = 0
            currentTime = 0
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func tickProgress() {
        guard isPlaying else { return }
        updateCurrentTimeFromNode()

        if isLoopEnabled, let start = loopStart, let end = loopEnd, hasValidLoop, currentTime >= end {
            seek(to: start)
        }
    }

    private func updateCurrentTimeFromNode() {
        guard
            let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
            sampleRate > 0
        else {
            return
        }

        let currentFrame = seekFrame + playerTime.sampleTime
        let clampedFrame = min(max(0, currentFrame), totalFrames)
        currentTime = Double(clampedFrame) / sampleRate
    }
}
