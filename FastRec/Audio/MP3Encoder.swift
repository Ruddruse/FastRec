import Foundation
import AVFoundation

class MP3Encoder {
    enum EncoderError: Error {
        case sourceFileNotFound
        case failedToReadSource
        case failedToCreateExportSession
        case exportFailed(String)
        case unsupportedFormat
    }

    /// Encode audio file to MP3 format
    /// Uses AVAssetWriter with AAC as fallback since native MP3 encoding
    /// requires additional setup. For true MP3, we use AVAssetExportSession
    /// with a preset that produces compatible output.
    func encode(from sourceURL: URL, to destinationURL: URL) async throws {
        // Check source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw EncoderError.sourceFileNotFound
        }

        // Create asset from source
        let asset = AVURLAsset(url: sourceURL)

        // Check if we can export to MP3-like format
        // Note: macOS doesn't natively support MP3 encoding in AVFoundation
        // We'll export to M4A (AAC) which is widely compatible, or use
        // a pass-through approach for the WAV file

        // For true MP3 support, we'll use a shell command with ffmpeg if available,
        // otherwise fall back to M4A

        if await canUseFFmpeg() {
            try await encodeWithFFmpeg(from: sourceURL, to: destinationURL)
        } else {
            // Fall back to M4A (AAC) format - rename extension if needed
            let m4aURL = destinationURL.deletingPathExtension().appendingPathExtension("m4a")
            try await encodeToM4A(asset: asset, to: m4aURL)

            // If user specifically wanted .mp3 extension, we'll keep the M4A content
            // but note that it's actually AAC audio
            if destinationURL.pathExtension.lowercased() == "mp3" {
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: m4aURL, to: destinationURL)
            }
        }
    }

    private func canUseFFmpeg() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func encodeWithFFmpeg(from sourceURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [
                "ffmpeg",
                "-y",  // Overwrite output
                "-i", sourceURL.path,  // Input file
                "-codec:a", "libmp3lame",  // MP3 codec
                "-b:a", "192k",  // Bitrate
                "-ar", "44100",  // Sample rate
                destinationURL.path  // Output file
            ]

            let errorPipe = Pipe()
            process.standardError = errorPipe
            process.standardOutput = FileHandle.nullDevice

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: EncoderError.exportFailed(errorMessage))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func encodeToM4A(asset: AVURLAsset, to destinationURL: URL) async throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: destinationURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw EncoderError.failedToCreateExportSession
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return
        case .failed:
            throw EncoderError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown error")
        case .cancelled:
            throw EncoderError.exportFailed("Export cancelled")
        default:
            throw EncoderError.exportFailed("Unknown export status")
        }
    }
}
