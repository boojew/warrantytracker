import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        #if os(macOS)
        TabView {
            DefaultsView().tabItem { Label("General", systemImage: "gearshape") }
            NavigationStack { CardsView() }.tabItem { Label("Cards", systemImage: "creditcard") }
            NavigationStack { organization }.tabItem { Label("Organization", systemImage: "tag") }
        }
        .padding().frame(width: 620, height: 600)
        #else
        List {
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

    var body: some View {
        List {
            ForEach(entries.filter { $0.kind == kind.rawValue && (showArchived || !$0.isArchived) }) { entry in
                HStack {
                    Button(entry.name + (entry.isArchived ? " (archived)" : "")) {
                        editing = entry; name = entry.name; showingEditor = true
                    }.buttonStyle(.plain)
                    Spacer()
                    Button(entry.isArchived ? "Restore" : "Archive") {
                        entry.isArchived.toggle()
                        do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
                    }.buttonStyle(.borderless)
                }
            }
            Toggle("Show archived entries", isOn: $showArchived)
            Text("Tap a name to rename it. Archived entries remain on existing items and can be restored.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle(kind.label)
        .toolbar {
            Button("Add Entry", systemImage: "plus") {
                editing = nil; name = ""; showingEditor = true
            }.accessibilityIdentifier("addCatalogEntry")
        }
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
                                } catch { context.rollback(); self.error = error.localizedDescription }
                            }.accessibilityIdentifier("saveCatalogEntry")
                        }
                    }
            }
            #if os(macOS)
            .frame(width: 400, height: 180)
            #endif
            .formError($error)
        }
        .formError($error)
    }
}
