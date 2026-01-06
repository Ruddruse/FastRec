import Cocoa
import SwiftUI

class RecorderWindow: NSPanel {
    init(recorderState: RecorderState) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Window configuration
        self.title = "FastRec"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = NSColor(calibratedWhite: 0.1, alpha: 0.95)

        // Rounded corners
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = 12
        self.contentView?.layer?.masksToBounds = true

        // SwiftUI content
        let contentView = ContentView(recorderState: recorderState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = self.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        self.contentView?.addSubview(hostingView)

        // Center on screen initially
        self.center()
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override func close() {
        self.orderOut(nil)
    }
}
