import Foundation
import AVFoundation

enum AudioFormat: String, CaseIterable {
    case wav = "WAV"
    case aiff = "AIFF"
    case m4a = "M4A (AAC)"

    var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .aiff: return "aiff"
        case .m4a: return "m4a"
        }
    }

    var utType: String {
        switch self {
        case .wav: return "public.wav"
        case .aiff: return "public.aiff-audio"
        case .m4a: return "public.mpeg-4-audio"
        }
    }
}

class AudioEncoder: @unchecked Sendable {
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

    /// Encode audio file to specified format
    func encode(from sourceURL: URL, to destinationURL: URL, format: AudioFormat) async throws {
        // Check source file exists
        guard FileManager.default.fileExists(atPath: sourceURL.path(percentEncoded: false)) else {
            print("AudioEncoder: Source file not found at \(sourceURL.path(percentEncoded: false))")
            throw EncoderError.sourceFileNotFound
        }

        // Get file size for debugging
        let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path(percentEncoded: false))
        let fileSize = attrs?[.size] as? Int64 ?? 0
        print("AudioEncoder: Source file size: \(fileSize) bytes, target format: \(format.rawValue)")

        switch format {
        case .wav:
            // Just copy the WAV file (already lossless)
            try copyFile(from: sourceURL, to: destinationURL)

        case .aiff:
            // Convert WAV to AIFF
            try await convertToAIFF(from: sourceURL, to: destinationURL)

        case .m4a:
            // Convert to M4A (AAC)
            try await exportToM4A(from: sourceURL, to: destinationURL)
        }

        print("AudioEncoder: Successfully saved to \(destinationURL.path(percentEncoded: false))")
    }

    private func copyFile(from sourceURL: URL, to destinationURL: URL) throws {
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func convertToAIFF(from sourceURL: URL, to destinationURL: URL) async throws {
        try? FileManager.default.removeItem(at: destinationURL)

        // Read source WAV file
        let sourceFile = try AVAudioFile(forReading: sourceURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = sourceFile.processingFormat
        let frameCount = AVAudioFrameCount(sourceFile.length)

        // Create AIFF settings
        let aiffSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: true  // AIFF uses big-endian
        ]

        // Create output file
        let outputFile = try AVAudioFile(
            forWriting: destinationURL,
            settings: aiffSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        // Read and write in chunks
        let bufferSize: AVAudioFrameCount = 65536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            throw EncoderError.failedToCreateExportSession
        }

        var framesRemaining = frameCount
        while framesRemaining > 0 {
            let framesToRead = min(bufferSize, framesRemaining)
            try sourceFile.read(into: buffer, frameCount: framesToRead)
            try outputFile.write(from: buffer)
            framesRemaining -= framesToRead
        }
    }

    private func exportToM4A(from sourceURL: URL, to destinationURL: URL) async throws {
        try? FileManager.default.removeItem(at: destinationURL)

        let asset = AVURLAsset(url: sourceURL)

        // Load tracks to ensure asset is ready
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else {
            print("AudioEncoder: No audio tracks found in source")
            throw EncoderError.failedToReadSource
        }

        print("AudioEncoder: Found \(tracks.count) audio track(s)")

        // Create export session - use the modern initializer
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("AudioEncoder: Failed to create export session")
            throw EncoderError.failedToCreateExportSession
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a

        // Export the audio using the modern async export method
        await exportSession.export()

        // Check the result
        switch exportSession.status {
        case .completed:
            print("AudioEncoder: Export completed successfully")
        case .failed:
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown error"
            print("AudioEncoder: Export failed: \(errorMessage)")
            throw EncoderError.exportFailed(errorMessage)
        case .cancelled:
            print("AudioEncoder: Export was cancelled")
            throw EncoderError.exportFailed("Export cancelled")
        default:
            print("AudioEncoder: Export ended with unexpected status: \(exportSession.status.rawValue)")
            throw EncoderError.exportFailed("Unexpected status")
        }
    }
}
