import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var context
    @State private var searchField: SearchField = .all
    @State private var error: String?
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var selectedID: UUID?
    @State private var showingAdd = false
    @State private var search = ""

    private var visibleItems: [Item] {
        items.filter { InventorySearch.matches($0, query: search, field: searchField) }
    }

    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView {
                inventoryList
                    .navigationSplitViewColumnWidth(min: 270, ideal: 320, max: 420)
            } detail: {
                if let item = items.first(where: { $0.id == selectedID }) {
                    NavigationStack { ItemDetailView(item: item) }.id(item.id)
                } else {
                    ContentUnavailableView("Your warranties, in one place", systemImage: "shippingbox",
                                           description: Text("Select an item to see its purchase details and warranty."))
                }
            }
            #else
            TabView {
                Tab("Items", systemImage: "shippingbox") {
                    NavigationStack {
                        inventoryList
                    }
                }
                Tab("Settings", systemImage: "gearshape") {
                    NavigationStack { SettingsView() }
                }
            }
            #endif
        }
        .task {
            do { try Catalog.initialize(in: context) } catch { context.rollback(); self.error = error.localizedDescription }
        }
        .formError($error, title: "Unable to load settings")
        .sheet(isPresented: $showingAdd) {
            ItemEditorView { id in selectedID = id }
        }
    }

    @ViewBuilder
    private var platformList: some View {
        #if os(macOS)
        List(selection: $selectedID) {
            ForEach(visibleItems) { item in
                NavigationLink(value: item.id) { ItemRow(item: item) }
                    .tag(item.id)
            }
        }
        #else
        List(visibleItems) { item in
            NavigationLink {
                ItemDetailView(item: item)
            } label: {
                ItemRow(item: item)
            }
        }
        #endif
    }

    private var inventoryList: some View {
        platformList
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Start your inventory", systemImage: "shippingbox")
                } description: {
                    Text("Keep purchase details and warranty dates together. Add your first item to begin.")
                } actions: {
                    Button("Add Item", systemImage: "plus") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("emptyAddItem")
                }
            } else if visibleItems.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Search items")
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Search in", selection: $searchField) {
                ForEach(SearchField.allCases) { Text($0.label).tag($0) }
            }
            .accessibilityIdentifier("searchField")
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle("Items")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Item", systemImage: "plus") { showingAdd = true }
                    .accessibilityIdentifier("addItem")
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            AttachmentThumbnail(data: item.mainPhoto?.thumbnail)
                .frame(width: 44, height: 48).clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                if !item.retailer.isEmpty { Text(item.retailer).font(.subheadline).foregroundStyle(.secondary) }
                Text(item.orderedCoverages.isEmpty ? "No coverage recorded" : item.orderedCoverages.map { CoverageStatus.status(of: $0).label }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
    }
}
