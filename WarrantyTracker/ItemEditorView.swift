import SwiftUI
import SwiftData

struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var preferences: [Preferences]
    let item: Item?
    let onSave: (UUID) -> Void
    @State private var draft: ItemDraft
    @State private var loadedDefaults = false
    @State private var errorMessage: String?

    init(item: Item? = nil, onSave: @escaping (UUID) -> Void = { _ in }) {
        self.item = item
        self.onSave = onSave
        _draft = State(initialValue: ItemDraft(item: item))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $draft.name)
                        .accessibilityIdentifier("itemName")
                    TextField("Manufacturer", text: $draft.manufacturer)
                    TextField("Serial number", text: $draft.serialNumber)
                } header: { Text("Item") } footer: { Text("Only the item name is required. You can fill in the rest later.") }

                Section("Purchase") {
                    TextField("Store / retailer", text: $draft.retailer)
                        .accessibilityIdentifier("retailer")
                    CardVersionPicker(selection: $draft.purchaseCard)
                    CountryPicker(selection: $draft.countryCode)
                    CurrencyPicker(selection: $draft.currencyCode)
                    TextField("Pre-tax price", text: $draft.price)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .accessibilityIdentifier("price")
                    Toggle("Purchase date known", isOn: $draft.hasPurchaseDate)
                        .accessibilityIdentifier("purchaseDateKnown")
                    if draft.hasPurchaseDate {
                        DatePicker("Purchased on", selection: $draft.purchaseDate, displayedComponents: .date)
                            .environment(\.calendar, Calendar(identifier: .gregorian))
                    }
                }

                if item == nil {
                Section {
                    Toggle("End date known", isOn: $draft.hasWarrantyEnd)
                        .accessibilityIdentifier("warrantyEndKnown")
                    if draft.hasWarrantyEnd {
                        DatePicker("Covered through", selection: $draft.warrantyEnd, displayedComponents: .date)
                            .environment(\.calendar, Calendar(identifier: .gregorian))
                    }
                } header: { Text("Manufacturer warranty") } footer: {
                    Text("Enter the end date from your warranty documents. An unknown date does not mean lifetime coverage.")
                }

                }

                Section("Organization") {
                    ClassificationPicker(title: "Category", kind: .category, selection: $draft.category)
                    ClassificationPicker(title: "Used at", kind: .location, selection: $draft.location)
                    NavigationLink { TagPicker(selection: $draft.tags) } label: {
                        LabeledContent("Tags", value: draft.tags.isEmpty ? "None" : draft.tags.map(\.name).joined(separator: ", "))
                    }
                    Text("Manage cards and these lists in Settings.").font(.footnote).foregroundStyle(.secondary)
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 80)
                        .accessibilityLabel("Notes")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveItem")
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 540, minHeight: 640, idealHeight: 730)
        #endif
        .interactiveDismissDisabled()
        .onAppear {
            if !loadedDefaults && item == nil { draft = ItemDraft(defaults: preferences.first) }
            loadedDefaults = true
        }
        .alert("Unable to save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        do { try draft.validate() } catch {
            errorMessage = error.localizedDescription
            return
        }
        do {
            let savedItem = item ?? Item(name: draft.name)
            if item == nil { context.insert(savedItem) }
            try draft.apply(to: savedItem)
            try context.save()
            onSave(savedItem.id)
            dismiss()
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
