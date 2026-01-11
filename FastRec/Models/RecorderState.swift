import Foundation
import AVFoundation
import Combine

enum RecordingState {
    case idle
    case recording
    case recorded
    case playing
}

@MainActor
class RecorderState: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var waveformSamples: [Float] = []
    @Published var recordedAudioURL: URL?

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var audioCapture: SystemAudioCapture?
    private var audioRecorder: AudioRecorder?
    private var playbackDelegate: PlaybackDelegate?  // Retain delegate to prevent deallocation

    // Waveform display samples (for visualization)
    private let maxWaveformSamples = 50

    init() {
        audioCapture = SystemAudioCapture()
        audioRecorder = AudioRecorder()

        // Set up audio capture callback
        audioCapture?.onAudioSamples = { [weak self] samples in
            Task { @MainActor in
                self?.updateWaveform(with: samples)
            }
        }

        audioCapture?.onAudioBuffer = { [weak self] buffer in
            self?.audioRecorder?.appendBuffer(buffer)
        }
    }

    func startRecording() async {
        guard state == .idle else { return }

        do {
            // Clear previous recording
            clearRecording()

            // Start audio capture
            try await audioCapture?.startCapture()
            audioRecorder?.startRecording()

            state = .recording
            elapsedTime = 0
            startTimer()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() async {
        guard state == .recording else { return }

        stopTimer()

        await audioCapture?.stopCapture()

        // Save to temporary file
        if let url = audioRecorder?.stopRecording() {
            recordedAudioURL = url
            state = .recorded
        } else {
            state = .idle
        }
    }

    func startPlayback() {
        guard state == .recorded, let url = recordedAudioURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            playbackDelegate = PlaybackDelegate(state: self)  // Store reference
            audioPlayer?.delegate = playbackDelegate
            audioPlayer?.play()
            state = .playing
            elapsedTime = 0
            startPlaybackTimer()
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackDelegate = nil
        stopTimer()
        state = .recorded
    }

    func clearRecording() {
        stopPlayback()
        audioPlayer = nil
        audioRecorder?.clear()

        // Delete temp file
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordedAudioURL = nil
        waveformSamples = []
        elapsedTime = 0
        state = .idle
    }

    func saveRecording(to url: URL, format: AudioFormat) async -> Bool {
        guard let sourceURL = recordedAudioURL else { return false }

        do {
            let encoder = AudioEncoder()
            try await encoder.encode(from: sourceURL, to: url, format: format)
            return true
        } catch {
            print("Failed to save recording: \(error)")
            return false
        }
    }

    private func updateWaveform(with samples: [Float]) {
        // Add new samples and maintain max count
        waveformSamples.append(contentsOf: samples)
        if waveformSamples.count > maxWaveformSamples {
            waveformSamples = Array(waveformSamples.suffix(maxWaveformSamples))
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime += 1
            }
        }
    }

    private func startPlaybackTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                self.elapsedTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func playbackDidFinish() {
        stopTimer()
        state = .recorded
    }
}

// MARK: - Playback Delegate
private class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    weak var state: RecorderState?

    init(state: RecorderState) {
        self.state = state
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            state?.playbackDidFinish()
        }
    }
}
