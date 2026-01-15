import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var recorderState: RecorderState
    
    // MARK: - Layout Constants
    private let rowHeight: CGFloat = 28
    private let spacing: CGFloat = 12
    private let cornerRadius: CGFloat = 6
    
    var body: some View {
        VStack(spacing: spacing) {
            waveformRow
            controlsRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }
    
    // MARK: - View Components
    
    private var waveformRow: some View {
        HStack(spacing: spacing) {
            WaveformView(
                samples: recorderState.waveformSamples,
                state: recorderState.state
            )
            .frame(maxWidth: 150)
            
            RecordButton(state: recorderState.state) {
                Task {
                    await handleMainButtonTap()
                }
            }
        }
        .frame(height: rowHeight)
    }
    
    private var controlsRow: some View {
        HStack(spacing: spacing) {
            Spacer()
            timerDisplay
            Spacer()
            clearButton
            saveButton
        }
        .frame(height: rowHeight)
    }
    
    private var timerDisplay: some View {
        Text(formatTime(recorderState.elapsedTime))
            .font(.system(size: 17, weight: .regular, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(minWidth: 60, alignment: .leading)
    }
    
    private var clearButton: some View {
        ControlButton(
            title: "Clear",
            isEnabled: canClear
        ) {
            recorderState.clearRecording()
        }
    }
    
    private var saveButton: some View {
        ControlButton(
            title: "Save",
            isEnabled: canSave,
            isProminent: true
        ) {
            presentSavePanel()
        }
    }
    
    // MARK: - State Helpers
    
    private var canClear: Bool {
        recorderState.state == .recorded || recorderState.state == .playing
    }
    
    private var canSave: Bool {
        recorderState.state == .recorded
    }

    // MARK: - Actions
    
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
    
    // MARK: - Formatting
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Save Panel
    
    private func presentSavePanel() {
        let panel = configureSavePanel()
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            let response = panel.runModal()
            
            if response == .OK, let url = panel.url {
                handleSavePanelResponse(url: url, panel: panel)
            }
            
            // Clean up
            objc_setAssociatedObject(panel, "formatChangeHandler", nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    private func configureSavePanel() -> NSSavePanel {
        let formatPopup = createFormatPopup()
        let accessoryView = createAccessoryView(with: formatPopup)
        
        let panel = NSSavePanel()
        panel.accessoryView = accessoryView
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Recording.wav"
        panel.allowedContentTypes = [.wav]
        panel.level = .floating
        panel.isExtensionHidden = false
        
        // Set up handler
        let handler = FormatChangeHandler(panel: panel)
        formatPopup.target = handler
        formatPopup.action = #selector(FormatChangeHandler.formatChanged(_:))
        objc_setAssociatedObject(panel, "formatChangeHandler", handler, .OBJC_ASSOCIATION_RETAIN)
        
        return panel
    }
    
    private func createFormatPopup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24), pullsDown: false)
        for format in AudioFormat.allCases {
            popup.addItem(withTitle: format.rawValue)
        }
        popup.selectItem(at: 0)
        return popup
    }
    
    private func createAccessoryView(with formatPopup: NSPopUpButton) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 6, width: 50, height: 20)
        formatPopup.frame = NSRect(x: 55, y: 2, width: 150, height: 26)
        view.addSubview(label)
        view.addSubview(formatPopup)
        return view
    }
    
    private func handleSavePanelResponse(url: URL, panel: NSSavePanel) {
        guard let formatPopup = panel.accessoryView?.subviews
            .compactMap({ $0 as? NSPopUpButton }).first else { return }
        
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
}

// MARK: - Control Button Component

private struct ControlButton: View {
    let title: String
    let isEnabled: Bool
    var isProminent: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(buttonBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(borderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
        .fixedSize()
    }
    
    private var textColor: Color {
        if !isEnabled {
            return Color.white.opacity(0.4)
        }
        
        if isProminent {
            return .white
        } else {
            return .white.opacity(0.9)
        }
    }
    
    private var buttonBackground: Color {
        if !isEnabled {
            return Color.white.opacity(0.08)
        }
        
        if isProminent {
            return Color.blue.opacity(0.8)
        } else {
            return Color.white.opacity(0.15)
        }
    }
    
    private var borderColor: Color {
        if isProminent && isEnabled {
            return Color.white.opacity(0.2)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Format Change Handler
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
