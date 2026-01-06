import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var recorderWindow: RecorderWindow?
    private var recorderState = RecorderState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupRecorderWindow()

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "FastRec")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(toggleRecorderWindow)
            button.target = self
        }
    }

    private func setupRecorderWindow() {
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
