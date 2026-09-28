import SwiftUI
import SwiftData

extension View {
    func formError(_ error: Binding<String?>, title: String = "Unable to save") -> some View {
        alert(title, isPresented: Binding(get: { error.wrappedValue != nil }, set: { if !$0 { error.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error.wrappedValue ?? "") }
    }
}

struct CardVersionPicker: View {
    var title = "Purchased with"
    @Binding var selection: CardVersion?
    @Query(sort: \CardVersion.createdAt, order: .reverse) private var versions: [CardVersion]

    var body: some View {
        Picker(title, selection: Binding<UUID?>(get: { selection?.id }, set: { id in selection = versions.first { $0.id == id } })) {
            Text("No card selected").tag(nil as UUID?)
            ForEach(versions.filter { $0.account?.isArchived != true || $0.id == selection?.id }) { version in
                Text(version.label + (version.account?.currentVersion?.id == version.id ? "" : " (previous)") + (version.account?.isArchived == true ? " (archived)" : ""))
                    .tag(Optional(version.id))
            }
        }
        .accessibilityIdentifier("purchaseCardPicker")
    }
}

struct ClassificationPicker: View {
    let title: String
    let kind: CatalogKind
    @Binding var selection: Classification?
    @Query(sort: \Classification.name) private var entries: [Classification]

    var body: some View {
        Picker(title, selection: Binding<UUID?>(get: { selection?.id }, set: { id in selection = entries.first { $0.id == id } })) {
            Text("Not set").tag(nil as UUID?)
            ForEach(entries.filter { $0.kind == kind.rawValue && (!$0.isArchived || $0.id == selection?.id) }) { entry in
                Text(entry.name + (entry.isArchived ? " (archived)" : "")).tag(Optional(entry.id))
            }
        }
    }
}

struct TagPicker: View {
    @Binding var selection: [Classification]
    @Query(sort: \Classification.name) private var entries: [Classification]

    var body: some View {
        List {
            ForEach(entries.filter { $0.kind == "tag" && (!$0.isArchived || selection.contains($0)) }) { entry in
                Toggle(entry.name + (entry.isArchived ? " (archived)" : ""), isOn: Binding(get: {
                    selection.contains { $0.id == entry.id }
                }, set: { enabled in
                    selection.removeAll { $0.id == entry.id }
                    if enabled { selection.append(entry) }
                }))
            }
        }
        .navigationTitle("Tags")
    }
}
