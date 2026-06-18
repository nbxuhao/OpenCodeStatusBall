import AppKit
import SwiftUI

/// Borderless transparent NSPanel that floats above all windows
/// (including fullscreen apps) on every Space.
///
/// The window frame actively follows the SwiftUI content's fitting size.
/// We anchor by the *top-right* corner so the capsule grows leftward and
/// downward as more session dots are added — preventing clipping.
final class FloatingBallPanel: NSPanel {
    override var canBecomeKey: Bool  { false }
    override var canBecomeMain: Bool { false }

    private var hostingView: NSView?

    init<Content: View>(rootView: Content) {
        let initial = NSRect(x: 0, y: 0, width: 120, height: 60)
        super.init(
            contentRect: initial,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovable = true
        isMovableByWindowBackground = true
        animationBehavior = .none
        worksWhenModal = true

        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = initial
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        hosting.layer?.isOpaque = false
        contentView = hosting
        hostingView = hosting

        // Park near upper-right of active screen by default.
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.maxX - initial.width - 16,
                y: visible.maxY - initial.height - 16
            )
            setFrameOrigin(origin)
        }

        // Initial sync after first layout pass.
        DispatchQueue.main.async { [weak self] in
            self?.resizeToFit()
        }
    }

    deinit {}

    /// Resize the window so contentView matches the SwiftUI fitting size,
    /// keeping the top-right corner pinned.
    func resizeToFit() {
        guard let hosting = hostingView else { return }
        var target = hosting.fittingSize
        target.width = max(target.width, 84)
        target.height = max(target.height, 50)
        guard target.width > 1, target.height > 1 else { return }

        let current = frame
        if abs(current.width - target.width) < 0.5,
           abs(current.height - target.height) < 0.5 {
            return
        }

        let topRightX = current.maxX
        let topRightY = current.maxY
        let newOrigin = NSPoint(
            x: topRightX - target.width,
            y: topRightY - target.height
        )
        let newFrame = NSRect(origin: newOrigin, size: target)
        setFrame(newFrame, display: true, animate: false)
    }
}
