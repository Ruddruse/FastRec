import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var recorderState: RecorderState
    @State private var showingSavePanel = false

    var body: some View {
        VStack(spacing: 12) {
            // Top spacing for title bar area
            Spacer()
                .frame(height: 8)

            // Waveform view
            WaveformView(
                samples: recorderState.waveformSamples,
                state: recorderState.state
            )
            .frame(height: 50)
            .padding(.horizontal, 16)

            // Timer display
            Text(formatTime(recorderState.elapsedTime))
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundColor(.white)

            // Controls
            HStack(spacing: 24) {
                // Clear button
                Button(action: {
                    recorderState.clearRecording()
                }) {
                    Text("Clear")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 55)
                }
                .buttonStyle(.plain)
                .disabled(recorderState.state == .idle || recorderState.state == .recording)
                .opacity(recorderState.state == .idle || recorderState.state == .recording ? 0.3 : 1.0)

                // Record/Stop/Play button
                RecordButton(state: recorderState.state) {
                    Task {
                        await handleMainButtonTap()
                    }
                }

                // Save button
                Button(action: {
                    showingSavePanel = true
                }) {
                    HStack(spacing: 3) {
                        Text("Save as...")
                            .font(.system(size: 13))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(recorderState.state != .recorded)
                .opacity(recorderState.state != .recorded ? 0.3 : 1.0)
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1))
        .onChange(of: showingSavePanel) { _, newValue in
            if newValue {
                presentSavePanel()
            }
        }
    }

    private func handleMainButtonTap() async {
        switch recorderState.state {
        case .idle:
            await recorderState.startRecording()
        case .recording:
            await recorderState.stopRecording()
        case .recorded:
            recorderState.startPlayback()
        case .playing:
            recorderState.stopPlayback()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Audio, .wav]
        panel.nameFieldStringValue = "Recording.m4a"
        panel.canCreateDirectories = true

        panel.begin { response in
            showingSavePanel = false
            if response == .OK, let url = panel.url {
                Task {
                    let success = await recorderState.saveRecording(to: url)
                    if !success {
                        print("Failed to save recording")
                    }
                }
            }
        }
    }
}
