import AVFoundation
import Foundation
import Testing
@testable import AudioSlowDownCore

@Suite("AudioPlayerEngine Tests")
struct AudioPlayerEngineTests {
    private func makeTemporaryWavFile(durationSeconds: Double = 2.0, sampleRate: Double = 44_100) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).wav")

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            throw NSError(domain: "AudioPlayerEngineTests", code: 1)
        }
        let frameCount = AVAudioFrameCount(durationSeconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "AudioPlayerEngineTests", code: 2)
        }
        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData?[0] {
            let frequency: Double = 440.0
            for i in 0..<Int(frameCount) {
                channelData[i] = Float(sin(2.0 * .pi * frequency * Double(i) / sampleRate) * 0.5)
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    @Test("Time formatting handles seconds, minutes, and hours")
    func testTimeFormatting() {
        #expect(TimeFormatting.format(0) == "0:00")
        #expect(TimeFormatting.format(5.9) == "0:05")
        #expect(TimeFormatting.format(65) == "1:05")
        #expect(TimeFormatting.format(3661) == "1:01:01")
        #expect(TimeFormatting.format(-10) == "0:00")
    }

    @Test("Playback rate clamps cleanly and keeps pitch locked at 0 cents")
    @MainActor
    func testRateClampingAndPitchLock() {
        let engine = AudioPlayerEngine()

        engine.playbackRate = 0.5
        #expect(engine.playbackRate == 0.5)
        #expect(engine.pitchCents == 0.0)

        engine.playbackRate = 0.1
        #expect(engine.playbackRate == AudioPlayerEngine.minRate)
        #expect(engine.pitchCents == 0.0)

        engine.playbackRate = 5.0
        #expect(engine.playbackRate == AudioPlayerEngine.maxRate)
        #expect(engine.pitchCents == 0.0)

        engine.resetRate()
        #expect(engine.playbackRate == 1.0)
        #expect(engine.pitchCents == 0.0)
    }

    @Test("Loading a WAV file populates duration, seeking, and A-B loop state")
    @MainActor
    func testLoadSeekAndLoop() throws {
        let url = try makeTemporaryWavFile(durationSeconds: 2.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = AudioPlayerEngine()
        engine.loadFile(url: url)

        #expect(engine.hasFileLoaded)
        #expect(engine.errorMessage == nil)
        #expect(abs(engine.duration - 2.0) < 0.02)
        #expect(engine.pitchCents == 0.0)

        engine.seek(to: 1.25)
        #expect(abs(engine.currentTime - 1.25) < 0.01)

        engine.seek(to: 99.0)
        #expect(abs(engine.currentTime - engine.duration) < 0.01)

        engine.seek(to: 0.4)
        engine.setLoopStartAtCurrentTime()
        engine.seek(to: 1.4)
        engine.setLoopEndAtCurrentTime()

        #expect(engine.hasValidLoop)
        #expect(engine.isLoopEnabled)

        engine.clearLoop()
        #expect(!engine.hasValidLoop)
        #expect(!engine.isLoopEnabled)
    }

    @Test("Slider position aligns each speed preset to its button index")
    @MainActor
    func testSliderPresetMapping() {
        for (index, preset) in AudioPlayerEngine.speedPresets.enumerated() {
            let pos = AudioPlayerEngine.sliderPosition(forRate: preset)
            #expect(abs(pos - Double(index)) < 0.0001)
            let roundTrip = AudioPlayerEngine.rate(forSliderPosition: pos)
            #expect(abs(roundTrip - preset) < 0.005)
        }

        // Midpoint between 1.0x (index 6) and 1.5x (index 7) should be 1.25x
        let midpointRate = AudioPlayerEngine.rate(forSliderPosition: 6.5)
        #expect(abs(midpointRate - 1.25) < 0.005)
    }

    @Test("WaveformExtractor returns normalized amplitude buckets")
    func testWaveformExtraction() async throws {
        let url = try makeTemporaryWavFile(durationSeconds: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try await WaveformExtractor.extractSamples(from: url, sampleCount: 60)
        #expect(samples.count == 60)
        #expect(samples.allSatisfy { $0 >= 0.05 && $0 <= 1.0 })
        #expect((samples.max() ?? 0) > 0.9)
    }
}
