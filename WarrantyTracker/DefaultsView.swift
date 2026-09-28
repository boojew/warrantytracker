import SwiftUI
import SwiftData

struct DefaultsView: View {
    @Environment(\.modelContext) private var context
    @Query private var preferences: [Preferences]
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                CountryPicker(selection: setting(\.countryCode, fallback: "CA"))
                CurrencyPicker(selection: setting(\.currencyCode, fallback: "CAD"))
            } header: { Text("New purchases") } footer: {
                Text("These defaults apply to new items. Existing purchases keep their country and currency.")
            }
            Section("Storage") {
                LabeledContent("Inventory", value: "On this device")
            }
        }
        .formStyle(.grouped)
        .alert("Unable to save settings", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func setting(_ keyPath: ReferenceWritableKeyPath<Preferences, String>, fallback: String) -> Binding<String> {
        Binding(get: { preferences.first?[keyPath: keyPath] ?? fallback }, set: { value in
            let settings = preferences.first ?? Preferences()
            if preferences.isEmpty { context.insert(settings) }
            settings[keyPath: keyPath] = value
            do { try context.save() } catch {
                context.rollback()
                errorMessage = error.localizedDescription
            }
        })
    }
}

struct CountryPicker: View {
    @Binding var selection: String
    private var countries: [String] {
        Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 }.sorted {
            label($0).localizedStandardCompare(label($1)) == .orderedAscending
        }
    }
    private func label(_ code: String) -> String { Locale.current.localizedString(forRegionCode: code) ?? code }

    var body: some View {
        Picker("Country", selection: $selection) {
            ForEach(countries, id: \.self) { Text(label($0)).tag($0) }
        }
    }
}

struct CurrencyPicker: View {
    @Binding var selection: String
    var body: some View {
        Picker("Currency", selection: $selection) {
            ForEach(Locale.Currency.isoCurrencies.map(\.identifier).sorted(), id: \.self) { code in
                Text("\(code) — \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
            }
        }
    }
}
