import AppKit
import Carbon
import Combine
import SwiftUI

@main
enum MacClipboardMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // bez ikony v Docku
        app.run()
    }
}

/// Panel, který přijímá klávesnici, ale neaktivuje aplikaci –
/// původní aplikace zůstane v popředí, takže do ní jde vložit.
final class ClipPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { standardWindowButton($0)?.isHidden = true }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private lazy var model = PanelModel(store: store)
    private let panel = ClipPanel()
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    private let hotKeyDescription = "⌃⌥V"
    private let collapsedHeight: CGFloat = 368
    private let expandedHeight: CGFloat = 600

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()

        model.onPick = { [weak self] item in self?.paste(item) }
        let host = NSHostingView(rootView: ClipListView(model: model, store: store))
        panel.contentView = host
        panel.onResignKey = { [weak self] in self?.hidePanel() }

        // Když se seznam rozbalí, okno se zvětší (horní okraj zůstane na místě).
        model.$expanded
            .removeDuplicates()
            .sink { [weak self] expanded in self?.resizePanel(expanded: expanded) }
            .store(in: &cancellables)

        // Control + Option + V
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey)) { [weak self] in
            self?.togglePanel()
        }

        setupStatusItem()

        // Pro ladění: `MacClipboard --show` otevře okno hned po startu.
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showPanel() }
        }

        // Při prvním spuštění požádej o oprávnění k automatickému vkládání (⌘V).
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Schránka")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = NSMenuItem(title: "Zobrazit historii  (\(hotKeyDescription))", action: #selector(openFromMenu), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        if hotKey?.isRegistered != true {
            let warn = NSMenuItem(title: "⚠︎ Zkratku \(hotKeyDescription) se nepodařilo zaregistrovat", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        }

        let count = NSMenuItem(title: "Uloženo v paměti: \(store.items.count) / \(store.maxItems)", action: nil, keyEquivalent: "")
        count.isEnabled = false
        menu.addItem(count)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pozastavit ukládání", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = store.isPaused ? .on : .off
        menu.addItem(pause)

        let clear = NSMenuItem(title: "Vymazat historii", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !store.items.isEmpty
        menu.addItem(clear)

        if !AXIsProcessTrusted() {
            menu.addItem(.separator())
            let ax = NSMenuItem(title: "Povolit automatické vkládání…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            ax.target = self
            menu.addItem(ax)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Ukončit (historie se smaže)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func openFromMenu() {
        // Počkej, až se zavře menu, jinak by panel hned ztratil fokus.
        DispatchQueue.main.async { self.showPanel() }
    }

    @objc private func togglePause() { store.isPaused.toggle() }
    @objc private func clearHistory() { store.clear() }

    @objc private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Panel

    private func togglePanel() {
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        model.reset()
        let size = NSSize(width: 460, height: collapsedHeight)
        panel.setFrame(NSRect(origin: originNearMouse(for: size), size: size), display: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    private func hidePanel() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeKeyMonitor()
    }

    private func resizePanel(expanded: Bool) {
        guard panel.isVisible else { return }
        var frame = panel.frame
        let newHeight = expanded ? expandedHeight : collapsedHeight
        let top = frame.maxY
        frame.size.height = newHeight
        frame.origin.y = top - newHeight
        if let visible = panel.screen?.visibleFrame, frame.minY < visible.minY {
            frame.origin.y = visible.minY
        }
        panel.setFrame(frame, display: true, animate: true)
    }

    /// Umístí okno pod kurzor myši a udrží ho celé na obrazovce.
    private func originNearMouse(for size: NSSize) -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x = mouse.x - size.width / 2
        var y = mouse.y - size.height - 8
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        if y < visible.minY + 8 { y = min(mouse.y + 8, visible.maxY - size.height - 8) }
        y = max(y, visible.minY + 8)
        return NSPoint(x: x, y: y)
    }

    // MARK: - Klávesnice

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private static let digitKeys: [UInt16: Int] = [
        UInt16(kVK_ANSI_1): 0, UInt16(kVK_ANSI_2): 1, UInt16(kVK_ANSI_3): 2,
        UInt16(kVK_ANSI_4): 3, UInt16(kVK_ANSI_5): 4, UInt16(kVK_ANSI_6): 5,
        UInt16(kVK_ANSI_7): 6, UInt16(kVK_ANSI_8): 7, UInt16(kVK_ANSI_9): 8,
    ]

    private func handleKey(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case kVK_Escape:
            hidePanel()
        case kVK_DownArrow:
            model.move(1)
        case kVK_UpArrow:
            model.move(-1)
        case kVK_PageDown:
            model.move(5)
        case kVK_PageUp:
            model.move(-5)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            model.pickSelected()
        case kVK_Delete, kVK_ForwardDelete:
            model.deleteSelected()
        case kVK_ANSI_V where event.modifierFlags.contains(.control) && event.modifierFlags.contains(.option):
            hidePanel() // opětovné stisknutí zkratky okno zavře
        default:
            if let index = Self.digitKeys[event.keyCode] {
                model.pick(at: index)
            } else {
                return false
            }
        }
        return true
    }

    // MARK: - Vložení

    private func paste(_ item: ClipItem) {
        store.copyToPasteboard(item)
        hidePanel()
        guard AXIsProcessTrusted() else { return } // bez oprávnění je položka aspoň ve schránce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.simulateCommandV()
        }
    }

    private static func simulateCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
