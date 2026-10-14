import SwiftUI

/// Stav vyskakovacího okna (výběr, rozbalení).
final class PanelModel: ObservableObject {
    static let collapsedCount = 5

    @Published var selected = 0
    @Published var expanded = false
    let store: ClipboardStore
    var onPick: (ClipItem) -> Void = { _ in }

    init(store: ClipboardStore) {
        self.store = store
    }

    var visibleItems: [ClipItem] {
        expanded ? store.items : Array(store.items.prefix(Self.collapsedCount))
    }

    func reset() {
        selected = 0
        expanded = false
        objectWillChange.send()
    }

    func move(_ delta: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        let next = selected + delta
        // Šipkou dolů za 5. položku se seznam automaticky rozbalí.
        if next >= count, !expanded, store.items.count > count {
            expanded = true
            selected = next
            return
        }
        selected = min(max(next, 0), count - 1)
    }

    func pickSelected() {
        pick(at: selected)
    }

    func pick(at index: Int) {
        let items = visibleItems
        guard items.indices.contains(index) else { return }
        onPick(items[index])
    }

    func deleteSelected() {
        let items = visibleItems
        guard items.indices.contains(selected) else { return }
        store.remove(items[selected])
        selected = min(selected, max(visibleItems.count - 1, 0))
    }
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
        .frame(maxHeight: .infinity, alignment: .top)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    let items = model.visibleItems
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipRow(item: item, index: index, isSelected: index == model.selected)
                            .id(item.id)
                            .onTapGesture { model.pick(at: index) }
                            .onHover { if $0 { model.selected = index } }
                    }
                    if !model.expanded, store.items.count > PanelModel.collapsedCount {
                        Button {
                            model.expanded = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.down")
                                Text("Zobrazit více (\(store.items.count - PanelModel.collapsedCount))")
                            }
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selected) { index in
                let items = model.visibleItems
                guard items.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(items[index].id) }
            }
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
