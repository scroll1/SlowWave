import AVFoundation
import Foundation

/// Extracts normalized RMS amplitude buckets from an audio file for waveform rendering.
public enum WaveformExtractor {
    public static func extractSamples(from url: URL, sampleCount: Int = 120) async throws -> [Float] {
        guard sampleCount > 0 else { return [] }
        return try await Task.detached(priority: .userInitiated) {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let file = try AVAudioFile(forReading: url)
            let totalFrames = Int(file.length)
            guard totalFrames > 0 else { return Array(repeating: 0.05, count: sampleCount) }

            let format = file.processingFormat
            let channelCount = Int(format.channelCount)
            let framesPerBucket = max(1, totalFrames / sampleCount)
            let chunkSize: AVAudioFrameCount = 8192

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
                return Array(repeating: 0.05, count: sampleCount)
            }

            var sumSquares = Array(repeating: Double(0), count: sampleCount)
            var counts = Array(repeating: Int(0), count: sampleCount)
            var currentFrame = 0

            while currentFrame < totalFrames {
                let remaining = totalFrames - currentFrame
                let framesToRead = AVAudioFrameCount(min(Int(chunkSize), remaining))
                buffer.frameLength = 0
                try file.read(into: buffer, frameCount: framesToRead)

                let readCount = Int(buffer.frameLength)
                guard readCount > 0, let floatData = buffer.floatChannelData else { break }

                for frameIndex in 0..<readCount {
                    let globalFrame = currentFrame + frameIndex
                    let bucket = min(sampleCount - 1, globalFrame / framesPerBucket)
                    var sampleSum: Double = 0
                    for ch in 0..<channelCount {
                        let value = Double(floatData[ch][frameIndex])
                        sampleSum += value * value
                    }
                    sumSquares[bucket] += sampleSum / Double(max(1, channelCount))
                    counts[bucket] += 1
                }

                currentFrame += readCount
            }

            var rmsValues = (0..<sampleCount).map { idx -> Float in
                guard counts[idx] > 0 else { return 0 }
                return Float(sqrt(sumSquares[idx] / Double(counts[idx])))
            }

            let maxRMS = rmsValues.max() ?? 0
            if maxRMS > 0.0001 {
                rmsValues = rmsValues.map { max(0.05, min(1.0, $0 / maxRMS)) }
            } else {
                rmsValues = Array(repeating: 0.05, count: sampleCount)
            }

            return rmsValues
        }.value
    }
}
