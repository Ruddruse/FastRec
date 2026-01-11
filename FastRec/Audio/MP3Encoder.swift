import Foundation
import AVFoundation

class MP3Encoder {
    enum EncoderError: Error, LocalizedError {
        case sourceFileNotFound
        case failedToReadSource
        case failedToCreateExportSession
        case exportFailed(String)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .sourceFileNotFound:
                return "Source file not found"
            case .failedToReadSource:
                return "Failed to read source file"
            case .failedToCreateExportSession:
                return "Failed to create export session"
            case .exportFailed(let message):
                return "Export failed: \(message)"
            case .unsupportedFormat:
                return "Unsupported format"
            }
        }
    }

    /// Encode audio file to M4A format (AAC)
    /// Note: macOS doesn't natively support MP3 encoding, so we use M4A/AAC
    /// which is widely compatible and higher quality
    func encode(from sourceURL: URL, to destinationURL: URL) async throws {
        // Check source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("MP3Encoder: Source file not found at \(sourceURL.path)")
            throw EncoderError.sourceFileNotFound
        }

        // Get file size for debugging
        let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attrs?[.size] as? Int64 ?? 0
        print("MP3Encoder: Source file size: \(fileSize) bytes")

        // Determine output format based on extension
        let outputExtension = destinationURL.pathExtension.lowercased()

        if outputExtension == "wav" {
            // Just copy the WAV file
            try copyFile(from: sourceURL, to: destinationURL)
        } else {
            // Export to M4A (AAC)
            let actualDestination: URL
            if outputExtension == "mp3" || outputExtension == "m4a" {
                // Change extension to m4a for proper format
                actualDestination = destinationURL.deletingPathExtension().appendingPathExtension("m4a")
            } else {
                actualDestination = destinationURL.deletingPathExtension().appendingPathExtension("m4a")
            }

            try await exportToM4A(from: sourceURL, to: actualDestination)

            // If user wanted .mp3, rename the file
            if outputExtension == "mp3" && actualDestination != destinationURL {
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: actualDestination, to: destinationURL)
            }
        }

        print("MP3Encoder: Successfully saved to \(destinationURL.path)")
    }

    private func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func exportToM4A(from sourceURL: URL, to destinationURL: URL) async throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: destinationURL)

        // Create asset from source
        let asset = AVURLAsset(url: sourceURL)

        // Load tracks to ensure asset is ready
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else {
            print("MP3Encoder: No audio tracks found in source")
            throw EncoderError.failedToReadSource
        }

        print("MP3Encoder: Found \(tracks.count) audio track(s)")

        // Try export presets in order of preference
        let presets = [
            AVAssetExportPresetAppleM4A,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPresetMediumQuality
        ]

        for preset in presets {
            let compatible = await AVAssetExportSession.compatibility(
                ofExportPreset: preset,
                with: asset,
                outputFileType: .m4a
            )

            if compatible {
                print("MP3Encoder: Using preset: \(preset)")

                guard let exportSession = AVAssetExportSession(
                    asset: asset,
                    presetName: preset
                ) else {
                    continue
                }

                exportSession.outputURL = destinationURL
                exportSession.outputFileType = .m4a

                await exportSession.export()

                switch exportSession.status {
                case .completed:
                    return
                case .failed:
                    let error = exportSession.error?.localizedDescription ?? "Unknown error"
                    print("MP3Encoder: Export failed with preset \(preset): \(error)")
                    continue
                case .cancelled:
                    throw EncoderError.exportFailed("Export cancelled")
                default:
                    continue
                }
            }
        }

        // If all presets fail, just copy the WAV
        print("MP3Encoder: All export presets failed, copying WAV instead")
        let wavDestination = destinationURL.deletingPathExtension().appendingPathExtension("wav")
        try copyFile(from: sourceURL, to: wavDestination)
    }
}
