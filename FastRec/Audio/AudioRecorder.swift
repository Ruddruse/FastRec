import Foundation
import AVFoundation

class AudioRecorder: @unchecked Sendable {
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private let fileManager = FileManager.default
    private let recordingQueue = DispatchQueue(label: "com.fastrec.recording", qos: .userInitiated)

    // Recording format: 44.1kHz, 16-bit, stereo WAV (will convert to MP3 on save)
    private var recordingFormat: AVAudioFormat?

    init() {
        setupRecordingFormat()
    }

    private func setupRecordingFormat() {
        recordingFormat = AVAudioFormat(
            standardFormatWithSampleRate: 44100,
            channels: 2
        )
    }

    func startRecording() {
        recordingQueue.async { [weak self] in
            self?.createNewAudioFile()
        }
    }

    private func createNewAudioFile() {
        // Create temp file
        let tempDir = fileManager.temporaryDirectory
        let fileName = "FastRec_\(UUID().uuidString).wav"
        tempFileURL = tempDir.appendingPathComponent(fileName)

        guard let url = tempFileURL, let format = recordingFormat else {
            print("Failed to create temp file URL or format")
            return
        }

        do {
            // Create audio file with WAV format for lossless intermediate storage
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            audioFile = try AVAudioFile(
                forWriting: url,
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            print("Failed to create audio file: \(error)")
        }
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        recordingQueue.async { [weak self] in
            guard let self = self, let audioFile = self.audioFile else { return }

            do {
                try audioFile.write(from: buffer)
            } catch {
                print("Failed to write buffer: \(error)")
            }
        }
    }

    func stopRecording() -> URL? {
        var resultURL: URL?

        recordingQueue.sync { [weak self] in
            guard let self = self else { return }

            // Close the file
            self.audioFile = nil
            resultURL = self.tempFileURL
        }

        return resultURL
    }

    func clear() {
        recordingQueue.async { [weak self] in
            guard let self = self else { return }

            self.audioFile = nil

            // Delete temp file
            if let url = self.tempFileURL {
                try? self.fileManager.removeItem(at: url)
            }

            self.tempFileURL = nil
        }
    }
}
