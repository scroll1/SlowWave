import AVFoundation
import CSignalsmithStretch
import Foundation

/// Real-time thread-safe audio stretcher backed by Signalsmith Stretch (MIT).
/// Streams chunks from an AVAudioFile into an AVAudioSourceNode render callback
/// with sample-accurate fractional rate tracking and 0-cent pitch lock.
final class SignalsmithAudioRenderer: @unchecked Sendable {
    private let lock = NSLock()
    private var stretchHandle: OpaquePointer?
    private var audioFile: AVAudioFile?
    private var format: AVAudioFormat?
    private var channelCount: Int = 2
    private var sampleRate: Double = 44_100
    private var totalFrames: AVAudioFramePosition = 0

    private var sourceFramePosition: AVAudioFramePosition = 0
    private var fractionalInputFrames: Double = 0
    private var playbackRate: Double = 1.0
    private var isPlaying: Bool = false
    private var reachedEnd: Bool = false

    private var readBuffer: AVAudioPCMBuffer?
    private var readBufferCapacity: AVAudioFrameCount = 0
    private var inputPtrs: [UnsafePointer<Float>?] = []
    private var outputPtrs: [UnsafeMutablePointer<Float>?] = []
    private var zeroBuffer: [Float] = Array(repeating: 0, count: 4096)

    var onReachedEnd: (@Sendable () -> Void)?

    /// Creates an AVAudioSourceNode outside of @MainActor isolation so Swift 6 does not
    /// insert a main-queue assertion on CoreAudio's real-time render thread.
    func makeSourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            return self.render(frameCount: frameCount, audioBufferList: audioBufferList)
        }
    }

    deinit {
        lock.lock()
        if let handle = stretchHandle {
            ss_destroy(handle)
            stretchHandle = nil
        }
        lock.unlock()
    }

    func configure(file: AVAudioFile) {
        lock.lock()
        defer { lock.unlock() }

        if let handle = stretchHandle {
            ss_destroy(handle)
            stretchHandle = nil
        }

        let fmt = file.processingFormat
        let channels = max(1, Int(fmt.channelCount))
        let sr = fmt.sampleRate

        audioFile = file
        format = fmt
        channelCount = channels
        sampleRate = sr
        totalFrames = file.length
        sourceFramePosition = 0
        fractionalInputFrames = 0
        isPlaying = false
        reachedEnd = false

        stretchHandle = ss_create(Int32(channels), Float(sr))
        if let handle = stretchHandle {
            ss_set_transpose_factor(handle, 1.0)
        }

        readBufferCapacity = 8192
        readBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: readBufferCapacity)
        inputPtrs = Array(repeating: nil, count: channels)
        outputPtrs = Array(repeating: nil, count: channels)

        file.framePosition = 0
    }

    func setPlaybackRate(_ rate: Float) {
        lock.lock()
        playbackRate = Double(rate)
        lock.unlock()
    }

    func setPlaying(_ playing: Bool) {
        lock.lock()
        isPlaying = playing
        if playing {
            reachedEnd = false
        }
        lock.unlock()
    }

    func seek(toFrame frame: AVAudioFramePosition) {
        lock.lock()
        defer { lock.unlock() }

        let clamped = min(max(0, frame), totalFrames)
        sourceFramePosition = clamped
        fractionalInputFrames = 0
        reachedEnd = false

        if let file = audioFile {
            file.framePosition = clamped
        }
        if let handle = stretchHandle {
            ss_reset(handle)
            ss_set_transpose_factor(handle, 1.0)
            primeStretchWindowLocked(handle: handle)
        }
    }

    func currentTimeSeconds() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard sampleRate > 0 else { return 0 }
        let latency = stretchHandle.map { AVAudioFramePosition(ss_output_latency($0)) } ?? 0
        let adjusted = max(0, sourceFramePosition - Int64(Double(latency) * playbackRate))
        return Double(min(adjusted, totalFrames)) / sampleRate
    }

    func render(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let outFrames = Int(frameCount)

        // Zero output buffers first
        for buf in abl {
            if let data = buf.mData {
                memset(data, 0, Int(buf.mDataByteSize))
            }
        }

        lock.lock()
        guard isPlaying,
              !reachedEnd,
              let handle = stretchHandle,
              let file = audioFile,
              readBuffer != nil,
              outFrames > 0
        else {
            lock.unlock()
            return noErr
        }

        // Compute how many input frames to feed for this output block
        let exactInput = Double(outFrames) * playbackRate + fractionalInputFrames
        let inputFramesNeeded = max(0, Int(exactInput.rounded(.down)))
        fractionalInputFrames = exactInput - Double(inputFramesNeeded)

        let remaining = Int(max(0, totalFrames - sourceFramePosition))
        let framesToRead = min(inputFramesNeeded, remaining)

        if framesToRead > 0 {
            if AVAudioFrameCount(framesToRead) > readBufferCapacity, let fmt = format {
                readBufferCapacity = AVAudioFrameCount(framesToRead)
                readBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: readBufferCapacity)
            }
            if let activeBuffer = readBuffer {
                activeBuffer.frameLength = 0
                file.framePosition = sourceFramePosition
                do {
                    try file.read(into: activeBuffer, frameCount: AVAudioFrameCount(framesToRead))
                } catch {
                    lock.unlock()
                    return noErr
                }
                let actualRead = Int(activeBuffer.frameLength)
                sourceFramePosition += AVAudioFramePosition(actualRead)

                // Zero-pad tail if we reached EOF mid-block
                if actualRead < inputFramesNeeded, let chData = activeBuffer.floatChannelData {
                    let padCount = inputFramesNeeded - actualRead
                    for ch in 0..<channelCount {
                        memset(chData[ch].advanced(by: actualRead), 0, padCount * MemoryLayout<Float>.size)
                    }
                    activeBuffer.frameLength = AVAudioFrameCount(inputFramesNeeded)
                }

                if let chData = activeBuffer.floatChannelData {
                    for ch in 0..<channelCount {
                        inputPtrs[ch] = UnsafePointer(chData[ch])
                    }
                }
            }
        } else {
            // Feed silence if 0 input frames needed (e.g. very slow rate sub-frame) or EOF
            if inputFramesNeeded > zeroBuffer.count {
                zeroBuffer = Array(repeating: 0, count: inputFramesNeeded)
            }
            zeroBuffer.withUnsafeBufferPointer { zPtr in
                for ch in 0..<channelCount {
                    inputPtrs[ch] = zPtr.baseAddress
                }
            }
        }

        // Map output channel pointers (non-interleaved Float32 from AVAudioSourceNode)
        let bufferCount = min(channelCount, abl.count)
        for ch in 0..<bufferCount {
            outputPtrs[ch] = abl[ch].mData?.assumingMemoryBound(to: Float.self)
        }
        // If mono file outputting to stereo or vice versa, mirror safely
        if bufferCount < channelCount {
            for ch in bufferCount..<channelCount {
                outputPtrs[ch] = outputPtrs[0]
            }
        }

        inputPtrs.withUnsafeBufferPointer { inBuf in
            outputPtrs.withUnsafeBufferPointer { outBuf in
                guard let inBase = inBuf.baseAddress, let outBase = outBuf.baseAddress else { return }
                // Cast away optionality (all channels populated above)
                let rawIn = UnsafeRawPointer(inBase).assumingMemoryBound(to: UnsafePointer<Float>.self)
                let rawOut = UnsafeRawPointer(outBase).assumingMemoryBound(to: UnsafeMutablePointer<Float>.self)
                ss_process(handle, rawIn, Int32(inputFramesNeeded), rawOut, Int32(outFrames))
            }
        }

        var didReachEnd = false
        if sourceFramePosition >= totalFrames {
            reachedEnd = true
            isPlaying = false
            didReachEnd = true
        }
        let endCallback = onReachedEnd
        lock.unlock()

        if didReachEnd {
            endCallback?()
        }

        return noErr
    }

    private func primeStretchWindowLocked(handle: OpaquePointer) {
        guard let file = audioFile, readBuffer != nil else { return }
        let seekSamples = min(Int(ss_input_latency(handle)), Int(max(0, totalFrames - sourceFramePosition)))
        guard seekSamples > 0 else { return }

        if AVAudioFrameCount(seekSamples) > readBufferCapacity, let fmt = format {
            readBufferCapacity = AVAudioFrameCount(seekSamples)
            readBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: readBufferCapacity)
        }
        guard let activeBuffer = readBuffer else { return }
        activeBuffer.frameLength = 0
        file.framePosition = sourceFramePosition
        guard (try? file.read(into: activeBuffer, frameCount: AVAudioFrameCount(seekSamples))) != nil,
              activeBuffer.frameLength > 0,
              let chData = activeBuffer.floatChannelData
        else { return }

        for ch in 0..<channelCount {
            inputPtrs[ch] = UnsafePointer(chData[ch])
        }
        inputPtrs.withUnsafeBufferPointer { inBuf in
            guard let inBase = inBuf.baseAddress else { return }
            let rawIn = UnsafeRawPointer(inBase).assumingMemoryBound(to: UnsafePointer<Float>.self)
            ss_seek(handle, rawIn, Int32(activeBuffer.frameLength), playbackRate)
        }
        sourceFramePosition += AVAudioFramePosition(activeBuffer.frameLength)
        file.framePosition = sourceFramePosition
    }
}
