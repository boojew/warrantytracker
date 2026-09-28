import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var selectedID: UUID?
    @State private var showingAdd = false
    @State private var search = ""

    private var visibleItems: [Item] {
        guard !search.isEmpty else { return items }
        return items.filter { [$0.name, $0.manufacturer, $0.retailer, $0.serialNumber, $0.notes]
            .contains { $0.localizedStandardContains(search) } }
    }

    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView {
                inventoryList
                    .navigationSplitViewColumnWidth(min: 270, ideal: 320, max: 420)
            } detail: {
                if let item = items.first(where: { $0.id == selectedID }) {
                    ItemDetailView(item: item)
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
                    NavigationStack { DefaultsView().navigationTitle("Settings") }
                }
            }
            #endif
        }
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
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 44, height: 48)
                .background(.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                if !item.retailer.isEmpty { Text(item.retailer).font(.subheadline).foregroundStyle(.secondary) }
                Text(CoverageStatus.manufacturer(end: item.manufacturerCoverage?.endsOn).label)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
    }
}
