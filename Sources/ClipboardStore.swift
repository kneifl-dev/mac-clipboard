import AppKit
import Combine

/// Sleduje systémovou schránku a drží historii jen v paměti (RAM).
/// Po ukončení aplikace historie zmizí.
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []
    @Published var isPaused = false

    let maxItems = 100
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        // NSPasteboard nemá notifikace o změně, proto se kontroluje changeCount (velmi levná operace).
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard !isPaused else { return }

        let source = NSWorkspace.shared.frontmostApplication?.localizedName
        guard let item = ClipItem.capture(from: pasteboard, sourceApp: source) else { return }
        insert(item)
    }

    private func insert(_ item: ClipItem) {
        items.removeAll { $0.signature == item.signature }
        items.insert(item, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }

    /// Zapíše položku do schránky a přesune ji v historii nahoru.
    func copyToPasteboard(_ item: ClipItem) {
        item.write(to: pasteboard)
        lastChangeCount = pasteboard.changeCount
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }
}
