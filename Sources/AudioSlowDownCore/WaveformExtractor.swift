import Accelerate
import AVFoundation
import Foundation

/// Extracts normalized RMS amplitude buckets from an audio file for waveform rendering.
/// Uses Accelerate (`vDSP_svesq`) over large chunks for fast, SIMD-accelerated extraction.
public enum WaveformExtractor {
    private static let uncompressedExtensions: Set<String> = ["wav", "wave", "aif", "aiff", "caf"]

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
            let channelCount = max(1, Int(format.channelCount))
            let framesPerBucket = max(1, totalFrames / sampleCount)

            var sumSquares = [Double](repeating: 0, count: sampleCount)
            var counts = [Int](repeating: 0, count: sampleCount)

            let ext = url.pathExtension.lowercased()
            let canUseWindowedSeek = Self.uncompressedExtensions.contains(ext) && framesPerBucket > 2048

            if canUseWindowedSeek {
                // Fast path for long uncompressed PCM files (WAV/AIFF/CAF):
                // Sample a 1024-frame window per bucket via direct seek + vDSP SIMD.
                let windowFrames = min(1024, framesPerBucket)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(windowFrames)) else {
                    return Array(repeating: 0.05, count: sampleCount)
                }

                for bucket in 0..<sampleCount {
                    try Task.checkCancellation()
                    let startFrame = min(totalFrames - 1, bucket * framesPerBucket)
                    let toRead = min(windowFrames, totalFrames - startFrame)
                    guard toRead > 0 else { continue }

                    file.framePosition = AVAudioFramePosition(startFrame)
                    buffer.frameLength = 0
                    try file.read(into: buffer, frameCount: AVAudioFrameCount(toRead))
                    let readCount = Int(buffer.frameLength)
                    guard readCount > 0, let floatData = buffer.floatChannelData else { continue }

                    var bucketSq: Double = 0
                    for ch in 0..<channelCount {
                        var chSumSq: Float = 0
                        vDSP_svesq(floatData[ch], 1, &chSumSq, vDSP_Length(readCount))
                        bucketSq += Double(chSumSq)
                    }
                    sumSquares[bucket] = bucketSq / Double(channelCount)
                    counts[bucket] = readCount
                }
            } else {
                // Fast sequential SIMD path for MP3/M4A/FLAC and shorter files:
                // Read large 65,536-frame chunks and compute per-bucket sum-of-squares via vDSP_svesq.
                let chunkSize: AVAudioFrameCount = 65_536
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
                    return Array(repeating: 0.05, count: sampleCount)
                }

                var currentFrame = 0
                file.framePosition = 0

                while currentFrame < totalFrames {
                    try Task.checkCancellation()
                    let remaining = totalFrames - currentFrame
                    let framesToRead = AVAudioFrameCount(min(Int(chunkSize), remaining))
                    buffer.frameLength = 0
                    try file.read(into: buffer, frameCount: framesToRead)

                    let readCount = Int(buffer.frameLength)
                    guard readCount > 0, let floatData = buffer.floatChannelData else { break }

                    var localOffset = 0
                    while localOffset < readCount {
                        let globalFrame = currentFrame + localOffset
                        let bucket = min(sampleCount - 1, globalFrame / framesPerBucket)
                        let nextBucketStart = (bucket == sampleCount - 1) ? totalFrames : ((bucket + 1) * framesPerBucket)
                        let span = min(readCount - localOffset, max(1, nextBucketStart - globalFrame))

                        var spanSq: Double = 0
                        for ch in 0..<channelCount {
                            var chSumSq: Float = 0
                            vDSP_svesq(floatData[ch].advanced(by: localOffset), 1, &chSumSq, vDSP_Length(span))
                            spanSq += Double(chSumSq)
                        }
                        sumSquares[bucket] += spanSq / Double(channelCount)
                        counts[bucket] += span
                        localOffset += span
                    }

                    currentFrame += readCount
                }
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
