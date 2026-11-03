import SwiftUI

#if os(macOS)
import AppKit

struct MacWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowAttachmentView { window in
            configure(window: window)
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func configure(window: NSWindow) {
        let minimumSize = NSSize(width: 620, height: 700)

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = minimumSize
        window.contentMinSize = minimumSize
        // Transparent window; `AppBackdrop` draws the blurred glass behind the content.
        window.backgroundColor = .clear
        window.isOpaque = false

        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
    }
}

/// Blurs whatever sits behind the window. Kept active so the glass doesn't turn flat grey
/// when the window loses focus.
struct WindowGlassBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

/// Calls `onAttach` once, when the view joins a window, instead of on every SwiftUI update.
private final class WindowAttachmentView: NSView {
    private let onAttach: (NSWindow) -> Void
    private weak var configuredWindow: NSWindow?

    init(onAttach: @escaping (NSWindow) -> Void) {
        self.onAttach = onAttach
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, window !== configuredWindow else { return }
        configuredWindow = window
        onAttach(window)
    }
}

extension View {
    func configureMacWindow() -> some View {
        background(MacWindowConfigurator())
    }

    func configureMiniPlayerWindow() -> some View {
        background(MiniPlayerWindowConfigurator())
    }
}

/// The mini player's window while it's open. Kept as a reference because SwiftUI replaces the
/// window identifiers it hands out, so looking the window up by identifier misses it.
enum MiniPlayerWindow {
    static weak var current: NSWindow?

    static func close() {
        current?.close()
        current = nil
    }
}

/// Moves the window when dragged: the mini player is borderless, so it has no title bar to hold.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

struct MiniPlayerWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowAttachmentView { window in
            configure(window: window)
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func configure(window: NSWindow) {
        let playerSize = NSSize(width: 680, height: 74)

        MiniPlayerWindow.current = window
        window.styleMask = [.borderless]
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        // The capsule draws its own soft shadow inside the padded frame.
        window.hasShadow = false
        window.minSize = playerSize
        window.maxSize = playerSize
        window.setContentSize(playerSize)
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
#else
extension View {
    func configureMacWindow() -> some View {
        self
    }

    func configureMiniPlayerWindow() -> some View {
        self
    }
}
#endif
