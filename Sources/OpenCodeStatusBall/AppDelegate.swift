import AppKit
import SwiftUI

@main
struct OpenCodeStatusBallApp {
    static func main() {
        // Hide from Dock & ⌘-Tab; behave as an accessory utility.
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingBallPanel?
    private let server = StatusServer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = StatusModel.shared
        let panel = FloatingBallPanel(rootView: CapsuleBarView(model: model))
        panel.orderFrontRegardless()
        self.panel = panel

        model.onUpdate = { [weak panel] in
            panel?.resizeToFit()
        }

        server.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel?.close()
        panel = nil
        StatusModel.shared.onUpdate = nil
        server.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
