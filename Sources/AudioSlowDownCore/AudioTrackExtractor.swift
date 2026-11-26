import AVFoundation
import Foundation

public enum AudioTrackExtractionError: LocalizedError {
    case noAudioTrack
    case exportSessionUnavailable
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "This video file does not contain an audio track."
        case .exportSessionUnavailable:
            return "Could not initialize audio extraction for this file."
        case .exportFailed(let reason):
            return "Could not extract audio from video: \(reason)"
        }
    }
}

/// Extracts the audio track from video containers (e.g. MP4, MOV, M4V) into a temporary M4A file
/// so SlowWave can play and time-stretch the sound without displaying video.
public enum AudioTrackExtractor {
    public static func extractAudio(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw AudioTrackExtractionError.noAudioTrack
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("slowwave-extracted-\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw AudioTrackExtractionError.exportSessionUnavailable
        }

        if #available(macOS 15.0, *) {
            try await exportSession.export(to: tempURL, as: .m4a)
            return tempURL
        } else {
            exportSession.outputURL = tempURL
            exportSession.outputFileType = .m4a
            await exportSession.export()

            switch exportSession.status {
            case .completed:
                return tempURL
            case .failed:
                try? FileManager.default.removeItem(at: tempURL)
                throw AudioTrackExtractionError.exportFailed(
                    exportSession.error?.localizedDescription ?? "Unknown export error"
                )
            case .cancelled:
                try? FileManager.default.removeItem(at: tempURL)
                throw CancellationError()
            default:
                try? FileManager.default.removeItem(at: tempURL)
                throw AudioTrackExtractionError.exportFailed("Unexpected export status")
            }
        }
    }
}
