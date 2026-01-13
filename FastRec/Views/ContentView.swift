import SwiftUI
import AppKit

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
                    presentSavePanel()
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
        // Create format popup
        let formatPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24), pullsDown: false)
        for format in AudioFormat.allCases {
            formatPopup.addItem(withTitle: format.rawValue)
        }
        formatPopup.selectItem(at: 0)  // Default to WAV

        // Create accessory view with label and popup
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 6, width: 50, height: 20)
        formatPopup.frame = NSRect(x: 55, y: 2, width: 150, height: 26)
        accessoryView.addSubview(label)
        accessoryView.addSubview(formatPopup)

        // Configure save panel
        let panel = NSSavePanel()
        panel.accessoryView = accessoryView
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Recording.wav"
        panel.allowedContentTypes = [.wav]
        panel.level = .floating
        panel.isExtensionHidden = false

        // Create handler for this specific panel and retain it
        let handler = FormatChangeHandler(panel: panel)
        formatPopup.target = handler
        formatPopup.action = #selector(FormatChangeHandler.formatChanged(_:))
        
        // Retain handler using objc_setAssociatedObject to keep it alive
        objc_setAssociatedObject(panel, "formatChangeHandler", handler, .OBJC_ASSOCIATION_RETAIN)

        // Run modal on main thread for reliable input handling
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let response = panel.runModal()

            if response == .OK, let url = panel.url {
                let selectedIndex = formatPopup.indexOfSelectedItem
                let format = AudioFormat.allCases[selectedIndex]

                // Ensure correct extension
                var finalURL = url
                if url.pathExtension.lowercased() != format.fileExtension {
                    finalURL = url.deletingPathExtension().appendingPathExtension(format.fileExtension)
                }

                Task {
                    let success = await recorderState.saveRecording(to: finalURL, format: format)
                    if !success {
                        print("Failed to save recording")
                    }
                }
            }
            
            // Clean up retained object
            objc_setAssociatedObject(panel, "formatChangeHandler", nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// Helper class to handle format popup changes
class FormatChangeHandler: NSObject {
    weak var panel: NSSavePanel?
    
    init(panel: NSSavePanel) {
        self.panel = panel
        super.init()
    }

    @objc func formatChanged(_ sender: NSPopUpButton) {
        guard let panel = panel else { return }

        let selectedIndex = sender.indexOfSelectedItem
        let format = AudioFormat.allCases[selectedIndex]

        // Update allowed content type
        switch format {
        case .wav:
            panel.allowedContentTypes = [.wav]
        case .aiff:
            panel.allowedContentTypes = [.aiff]
        case .m4a:
            panel.allowedContentTypes = [.mpeg4Audio]
        }

        // Update filename extension
        let currentName = panel.nameFieldStringValue
        let baseName = (currentName as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(baseName).\(format.fileExtension)"
    }
}
