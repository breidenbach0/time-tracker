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
        window.backgroundColor = NSColor(AppTheme.primary)
        window.isOpaque = true

        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }

        tintTitlebarContainer(in: window)
    }

    private func tintTitlebarContainer(in window: NSWindow) {
        guard let titlebarContainer = window.standardWindowButton(.closeButton)?.superview else {
            return
        }

        titlebarContainer.wantsLayer = true
        titlebarContainer.layer?.backgroundColor = NSColor(AppTheme.primary).cgColor
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

struct MiniPlayerWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowAttachmentView { window in
            configure(window: window)
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func configure(window: NSWindow) {
        let playerSize = NSSize(width: 680, height: 74)

        window.identifier = NSUserInterfaceItemIdentifier("TimeTrackerMiniPlayer")
        window.styleMask = [.borderless]
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
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
