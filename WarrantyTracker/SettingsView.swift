import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var section = 0
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            Picker("Settings section", selection: $section) {
                Text("General").tag(0)
                Text("Cards").tag(1)
                Text("Organization").tag(2)
            }.pickerStyle(.segmented).padding()
            Divider()
            NavigationStack {
                switch section {
                case 1: CardsView()
                case 2: organization
                default: DefaultsView().navigationTitle("General")
                }
            }.id(section)
        }
        .frame(width: 620, height: 600)
        #else
        List {
            NavigationLink("Storage & Sync") { SyncSettingsView() }
            NavigationLink("Purchase defaults") { DefaultsView().navigationTitle("Purchase defaults") }
            NavigationLink("Credit Cards") { CardsView() }
            Section("Organization") { catalogLinks }
        }
        .navigationTitle("Settings")
        #endif
    }

    private var organization: some View {
        List { catalogLinks }.navigationTitle("Organization")
    }

    private var catalogLinks: some View {
        ForEach(CatalogKind.allCases) { kind in
            NavigationLink(kind.label) { CatalogView(kind: kind) }
        }
    }
}

struct CatalogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Classification.name) private var entries: [Classification]
    let kind: CatalogKind
    @State private var editing: Classification?
    @State private var showingEditor = false
    @State private var showArchived = false
    @State private var name = ""
    @State private var error: String?
    @State private var editingError: String?

    var body: some View {
        List {
            ForEach(SyncReconciliation.visible(entries).filter { $0.kind == kind.rawValue && (showArchived || !$0.isArchived) }) { entry in
                HStack {
                    Button(entry.name + (entry.isArchived ? " (archived)" : "")) {
                        editing = entry; name = entry.name; showingEditor = true
                    }.buttonStyle(.plain)
                    Spacer()
                    Button(entry.isArchived ? "Restore" : "Archive") {
                        do { try Catalog.setArchived(!entry.isArchived, entry: entry, in: context) } catch { context.rollback(); self.error = error.localizedDescription }
                    }.buttonStyle(.borderless)
                }
            }
            Toggle("Show archived entries", isOn: $showArchived)
            Text("Tap a name to rename it. Archived entries remain on existing items and can be restored.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle(kind.label)
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            HStack { addButton; Spacer() }.padding().background(.bar)
        }
        #else
        .toolbar { addButton }
        #endif
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                Form { TextField("Name", text: $name).accessibilityIdentifier("catalogName") }
                    .formStyle(.grouped)
                    .navigationTitle(editing == nil ? "Add Entry" : "Rename Entry")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingEditor = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                do {
                                    try Catalog.save(name: name, kind: kind, entry: editing, in: context)
                                    showingEditor = false
                                } catch { context.rollback(); editingError = error.localizedDescription }
                            }.accessibilityIdentifier("saveCatalogEntry")
                        }
                    }
            }
            #if os(macOS)
            .frame(width: 400, height: 180)
            #endif
            .formError($editingError)
        }
        .formError($error)
    }
    private var addButton: some View {
        Button("Add Entry", systemImage: "plus") {
            editing = nil; name = ""; showingEditor = true
        }.accessibilityIdentifier("addCatalogEntry")
    }

}
