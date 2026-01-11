import Cocoa
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var recorderWindow: RecorderWindow?
    private var recorderState: RecorderState?
    private var stateObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        recorderState = RecorderState()
        setupMenuBar()
        setupRecorderWindow()
        setupStateObserver()

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateMenuBarIcon(isRecording: false)
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupStateObserver() {
        stateObserver = recorderState?.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateMenuBarIcon(isRecording: state == .recording)
            }
    }

    private func updateMenuBarIcon(isRecording: Bool) {
        guard let button = statusItem?.button else { return }

        if isRecording {
            // Filled red circle when recording
            let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            // Apply red tint for recording state
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = image?.withSymbolConfiguration(config)
        } else {
            // Normal template icon when not recording
            let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "FastRec")
            image?.isTemplate = true
            button.image = image
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggleRecorderWindow()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show FastRec", action: #selector(toggleRecorderWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit FastRec", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // Remove menu so left-click works again
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func setupRecorderWindow() {
        guard let recorderState = recorderState else { return }
        recorderWindow = RecorderWindow(recorderState: recorderState)
    }

    @objc private func toggleRecorderWindow() {
        guard let window = recorderWindow else { return }

        if window.isVisible {
            window.orderOut(nil)
        } else {
            positionWindowNearStatusItem()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionWindowNearStatusItem() {
        guard let window = recorderWindow,
              let button = statusItem?.button,
              let buttonWindow = button.window else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        let windowWidth = window.frame.width
        let x = screenRect.midX - (windowWidth / 2)
        let y = screenRect.minY - 10

        window.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }
}
