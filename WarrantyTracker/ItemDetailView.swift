import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var showingEdit = false
    @State private var addingCoverage = false
    @State private var editingCoverage: Coverage?
    @State private var removingCoverage: Coverage?
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "shippingbox.fill")
                        .font(.largeTitle).foregroundStyle(.teal)
                        .frame(width: 68, height: 68)
                        .background(.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.title2.bold()).textSelection(.enabled)
                        Text(item.manufacturer.isEmpty ? "Manufacturer not entered" : item.manufacturer)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section("Purchase") {
                LabeledContent("Store", value: item.retailer.isEmpty ? "Not entered" : item.retailer)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("purchaseStore")
                LabeledContent("Country", value: Locale.current.localizedString(forRegionCode: item.countryCode) ?? item.countryCode)
                LabeledContent("Pre-tax price", value: Money.label(item.priceAmount, currency: item.currencyCode))
                LabeledContent("Purchased on", value: CalendarDay.label(item.purchasedOn))
                LabeledContent("Serial number", value: item.serialNumber.isEmpty ? "Not entered" : item.serialNumber)
            }
            if let card = item.purchaseCard, let account = card.account {
                Section("Purchased with") {
                    NavigationLink { CardDetailView(account: account) } label: { Text(card.label) }
                }
            }
            Section {
                ForEach(item.orderedCoverages) { coverage in
                    VStack(alignment: .leading) {
                        CoverageSummary(coverage: coverage)
                        HStack {
                            Button("Edit Coverage") { editingCoverage = coverage }
                            Spacer()
                            Button("Remove", role: .destructive) { removingCoverage = coverage }
                        }.buttonStyle(.borderless)
                    }
                }
                Button("Add Coverage", systemImage: "plus") { addingCoverage = true }
                    .accessibilityIdentifier("addCoverage")
            } header: { Text("Warranty coverage") } footer: {
                Text("Each plan is recorded separately. Dates and terms are entered by you; consult your policy documents to confirm coverage.")
            }
            Section("Organization") {
                LabeledContent("Category", value: item.category?.name ?? "Not set")
                LabeledContent("Used at", value: item.location?.name ?? "Not set")
                LabeledContent("Tags", value: (item.tags ?? []).map(\.name).sorted().joined(separator: ", "))
            }
            if !item.notes.isEmpty {
                Section("Notes") { Text(item.notes).textSelection(.enabled) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { showingEdit = true }
                    .accessibilityIdentifier("editItem")
                Button("Delete Item", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("deleteItem")
            }
        }
        .sheet(isPresented: $showingEdit) { ItemEditorView(item: item) }
        .sheet(isPresented: $addingCoverage) { CoverageEditorView(item: item) }
        .sheet(item: $editingCoverage) { CoverageEditorView(item: item, coverage: $0) }
        .confirmationDialog("Remove this coverage?", isPresented: Binding(get: { removingCoverage != nil }, set: { if !$0 { removingCoverage = nil } }), titleVisibility: .visible) {
            Button("Remove Coverage", role: .destructive) {
                guard let coverage = removingCoverage else { return }
                context.delete(coverage)
                item.updatedAt = Date()
                do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
                removingCoverage = nil
            }
            Button("Cancel", role: .cancel) { removingCoverage = nil }
        }
        .confirmationDialog("Delete \(item.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Item", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the item and its warranty records from this device.") }
        .alert("Unable to delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func delete() {
        do {
            context.delete(item)
            try context.save()
            #if os(iOS)
            dismiss()
            #endif
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
