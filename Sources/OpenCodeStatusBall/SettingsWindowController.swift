import AppKit
import SwiftUI

/// Settings window for OpenCodeStatusBall.
/// Allows adjusting UI scale and toggling auto-start at login.
final class SettingsWindowController {
    private var window: NSWindow?
    private let settingsView: SettingsView

    init() {
        let model = SettingsModel.shared
        self.settingsView = SettingsView(model: model)
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true

        let windowContent = NSView()
        windowContent.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: windowContent.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: windowContent.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: windowContent.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: windowContent.bottomAnchor),
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = windowContent
        window.level = .floating
        window.backgroundColor = NSColor.windowBackgroundColor

        // Hide titlebar buttons (keep close)
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}
