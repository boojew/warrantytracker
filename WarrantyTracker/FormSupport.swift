import SwiftUI
import SwiftData

struct OptionalPurchaseDateField: View {
    @Binding var date: Date?
    @State private var choosingDate = false
    @State private var proposedDate = Date()

    var body: some View {
        HStack {
            Text("Purchase date")
            Spacer()
            Button {
                proposedDate = date ?? Date()
                choosingDate = true
            } label: {
                if let date { Text(date, format: .dateTime.year().month().day()) }
                else { Text("Add date (optional)").foregroundStyle(.secondary) }
            }.accessibilityIdentifier("purchaseDate")
            if date != nil {
                Button("Clear purchase date", systemImage: "xmark.circle.fill") { date = nil }
                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                    .accessibilityIdentifier("clearPurchaseDate")
            }
        }
        .sheet(isPresented: $choosingDate) {
            NavigationStack {
                ScrollView {
                    DatePicker("Purchased on", selection: $proposedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, Calendar(identifier: .gregorian))
                        .padding()
                }
                .navigationTitle("Purchase date")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { choosingDate = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Set Date") { date = proposedDate; choosingDate = false }
                            .accessibilityIdentifier("setPurchaseDate")
                    }
                }
            }
            #if os(macOS)
            .frame(width: 380, height: 360)
            #else
            .presentationDetents([.large])
            #endif
        }
    }
}

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
            ForEach(SyncReconciliation.visible(entries, keeping: selection.map { [$0] } ?? []).filter { $0.kind == kind.rawValue && (!$0.isArchived || $0.id == selection?.id) }) { entry in
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
            ForEach(SyncReconciliation.visible(entries, keeping: selection).filter { $0.kind == "tag" && (!$0.isArchived || selection.contains($0)) }) { entry in
                Toggle(entry.name + (entry.isArchived ? " (archived)" : ""), isOn: Binding(get: {
                    selection.contains { SyncReconciliation.key($0) == SyncReconciliation.key(entry) }
                }, set: { enabled in
                    selection.removeAll { SyncReconciliation.key($0) == SyncReconciliation.key(entry) }
                    if enabled { selection.append(entry) }
                }))
            }
        }
        .navigationTitle("Tags")
    }
}
