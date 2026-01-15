import Foundation
import AVFoundation
import Combine
import AppKit

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
            
            // Show alert for permission issues
            if let captureError = error as? CaptureError {
                await showPermissionAlert(for: captureError)
            }
            
            state = .idle
        }
    }
    
    private func showPermissionAlert(for error: CaptureError) async {
        let alert = NSAlert()
        alert.messageText = "Recording Permission Required"
        
        switch error {
        case .permissionDenied:
            alert.informativeText = "FastRec needs Screen Recording permission to capture system audio. Please enable it in System Settings > Privacy & Security > Screen Recording."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        case .noDisplayFound:
            alert.informativeText = "No display was found for recording."
            alert.addButton(withTitle: "OK")
        case .failedToCreateOutput:
            alert.informativeText = "Failed to initialize audio recording system."
            alert.addButton(withTitle: "OK")
        }
        
        alert.alertStyle = .warning
        
        let response = await alert.runModal()
        if response == .alertFirstButtonReturn && error == .permissionDenied {
            // Open System Settings to Screen Recording
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
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
            // Configure audio session for playback
            #if os(macOS)
            // macOS doesn't require audio session configuration
            #else
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            
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
        audioRecorder?.clear()  // Handles temp file deletion
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
        let overflow = waveformSamples.count - maxWaveformSamples
        if overflow > 0 {
            waveformSamples.removeFirst(overflow)
        }
    }

    private func startTimer() {
        stopTimer()  // Ensure no existing timer
        let newTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedTime += 1
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func startPlaybackTimer() {
        stopTimer()  // Ensure no existing timer
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let player = self.audioPlayer else { return }
                self.elapsedTime = player.currentTime
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
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
