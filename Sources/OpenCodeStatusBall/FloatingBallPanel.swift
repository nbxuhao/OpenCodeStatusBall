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
    private var hasSavedPosition = false

    init<Content: View>(rootView: Content) {
        let scale = StatusModel.shared.uiScale
        let initial = NSRect(x: 0, y: 0, width: 120 * scale, height: 60 * scale)
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

        // Restore saved position or default to upper-right
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let savedX = UserDefaults.standard.double(forKey: "ballPositionX")
            let savedY = UserDefaults.standard.double(forKey: "ballPositionY")
            
            if savedX > 0 && savedY > 0 {
                let origin = NSPoint(x: savedX, y: savedY)
                if origin.x >= visible.minX && origin.x <= visible.maxX - initial.width &&
                   origin.y >= visible.minY && origin.y <= visible.maxY - initial.height {
                    setFrameOrigin(origin)
                    hasSavedPosition = true
                } else {
                    setFrameOrigin(NSPoint(x: visible.maxX - initial.width - 16, y: visible.maxY - initial.height - 16))
                }
            } else {
                setFrameOrigin(NSPoint(x: visible.maxX - initial.width - 16, y: visible.maxY - initial.height - 16))
            }
        }

        // Initial sync after first layout pass.
        DispatchQueue.main.async { [weak self] in
            self?.resizeToFit()
        }
    }

    deinit {
        // Save position before closing
        savePosition()
    }

    override func close() {
        savePosition()
        super.close()
    }

    private func savePosition() {
        let origin = frame.origin
        UserDefaults.standard.set(origin.x, forKey: "ballPositionX")
        UserDefaults.standard.set(origin.y, forKey: "ballPositionY")
    }

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
        
        if !hasSavedPosition {
            savePosition()
        }
    }
}
