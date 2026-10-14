import SwiftUI

/// Stav vyskakovacího okna. Položky se zobrazují po stránkách:
/// na začátku 5, při doscrollování na konec se přidá dalších 5.
final class PanelModel: ObservableObject {
    static let pageSize = 5

    @Published var selected = 0
    @Published private(set) var loadedCount = pageSize
    let store: ClipboardStore
    var onPick: (ClipItem) -> Void = { _ in }

    init(store: ClipboardStore) {
        self.store = store
    }

    var visibleItems: [ClipItem] {
        Array(store.items.prefix(loadedCount))
    }

    var hasMore: Bool {
        store.items.count > loadedCount
    }

    func loadMore() {
        guard hasMore else { return }
        loadedCount += Self.pageSize
    }

    /// Načte stránky tak, aby byla položka s daným indexem zobrazená.
    private func ensureLoaded(_ index: Int) {
        while index >= loadedCount, hasMore { loadMore() }
    }

    func reset() {
        selected = 0
        loadedCount = Self.pageSize
        objectWillChange.send()
    }

    func move(_ delta: Int) {
        guard !store.items.isEmpty else { return }
        let next = min(max(selected + delta, 0), store.items.count - 1)
        ensureLoaded(next)
        selected = next
    }

    func pickSelected() {
        pick(at: selected)
    }

    func pick(at index: Int) {
        guard store.items.indices.contains(index) else { return }
        onPick(store.items[index])
    }

    func deleteSelected() {
        guard store.items.indices.contains(selected) else { return }
        store.remove(store.items[selected])
        selected = min(selected, max(visibleItems.count - 1, 0))
    }
}

/// Pozice značky na konci seznamu (pro načítání při scrollu).
private struct BottomMarkerKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ClipListView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.items.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: 460)
        .background(VisualEffectBackground())
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .foregroundStyle(.secondary)
            Text("Schránka")
                .font(.headline)
            if store.isPaused {
                Text("pozastaveno")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.25)))
            }
            Spacer()
            Text(itemCountText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var itemCountText: String {
        let n = store.items.count
        switch n {
        case 1: return "1 položka"
        case 2...4: return "\(n) položky"
        default: return "\(n) položek"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Zatím tu nic není.")
                .font(.callout)
            Text("Zkopíruj něco pomocí ⌘C a objeví se to tady.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.listHeight)
    }

    private static let rowSpacing: CGFloat = 2
    private static let listPadding: CGFloat = 6
    private static let hintHeight: CGFloat = 26
    /// Výška seznamu = přesně 5 řádků + řádek s nápovědou; vše další je pod okrajem.
    private static let listHeight: CGFloat =
        CGFloat(PanelModel.pageSize) * ClipRow.height
        + CGFloat(PanelModel.pageSize - 1) * rowSpacing
        + listPadding + hintHeight

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Lazy: vykreslí se jen řádky, které jsou (skoro) vidět.
                    LazyVStack(spacing: Self.rowSpacing) {
                        ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                            ClipRow(item: item, index: index, isSelected: index == model.selected)
                                .id(item.id)
                                .onTapGesture { model.pick(at: index) }
                                .onHover { if $0 { model.selected = index } }
                        }
                    }
                    .padding(.horizontal, Self.listPadding)
                    .padding(.top, Self.listPadding)

                    hint
                        .frame(height: Self.hintHeight)

                    // Neviditelná značka těsně pod okrajem okna – jakmile se
                    // doscrolluje do zorného pole, načte se dalších 5 položek.
                    GeometryReader { geo in
                        Color.clear.preference(key: BottomMarkerKey.self,
                                               value: geo.frame(in: .named("clipScroll")).minY)
                    }
                    .frame(height: 1)
                }
            }
            .coordinateSpace(name: "clipScroll")
            .frame(height: Self.listHeight)
            .onPreferenceChange(BottomMarkerKey.self) { markerY in
                if markerY < Self.listHeight { model.loadMore() }
            }
            .onChange(of: model.selected) { index in
                let items = model.visibleItems
                guard items.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(items[index].id) }
            }
        }
    }

    @ViewBuilder private var hint: some View {
        let remaining = store.items.count - model.loadedCount
        if remaining > 0 {
            Label("Scrolluj pro další (\(remaining))", systemImage: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if store.items.count > PanelModel.pageSize {
            Text("Konec historie")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else {
            Color.clear
        }
    }

    private var footer: some View {
        Text("↑↓ výběr   ↩ vložit   1–9 rychlá volba   ⌫ smazat   esc zavřít")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
    }
}

struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "cs_CZ")
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    Text(item.kind.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(item.kind.tint.opacity(0.22)))
                    Text(metaText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            if index < 9 {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: ClipRow.height)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.28) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    static let height: CGFloat = 52

    private var metaText: String {
        var parts = [item.detail]
        if let app = item.sourceApp { parts.append(app) }
        let age = Date().timeIntervalSince(item.date)
        parts.append(age < 5 ? "právě teď" : Self.relative.localizedString(for: item.date, relativeTo: Date()))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var icon: some View {
        if let thumb = item.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: item.kind == .file ? .fit : .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 15))
                .foregroundStyle(item.kind.tint)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 6).fill(item.kind.tint.opacity(0.14)))
        }
    }
}

/// Průsvitné pozadí ve stylu macOS (jako Spotlight).
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
