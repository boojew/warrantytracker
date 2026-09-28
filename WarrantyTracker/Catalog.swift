import Foundation
import SwiftData

enum CatalogKind: String, CaseIterable, Identifiable {
    case category, tag, location
    var id: String { rawValue }
    var label: String {
        switch self {
        case .category: "Categories"
        case .tag: "Tags"
        case .location: "Usage locations"
        }
    }
    var defaults: [String] {
        switch self {
        case .category: ["Electronics", "Appliances", "Pool & garden", "Other"]
        case .tag: ["Household", "Important"]
        case .location: ["Home", "Office", "Garage", "Outdoors"]
        }
    }
}

@MainActor
enum Catalog {
    static func initialize(in context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<Preferences>()).first ?? Preferences()
        guard !settings.listsInitialized else { return }
        if settings.modelContext == nil { context.insert(settings) }
        let existing = try context.fetch(FetchDescriptor<Classification>())
        for kind in CatalogKind.allCases {
            for name in kind.defaults where !existing.contains(where: { $0.kind == kind.rawValue && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                context.insert(Classification(name: name, kind: kind.rawValue))
            }
        }
        settings.listsInitialized = true
        try context.save()
    }

    static func save(name: String, kind: CatalogKind, entry: Classification?, in context: ModelContext) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FormError.message("Enter a name.") }
        let existing = try context.fetch(FetchDescriptor<Classification>())
        guard !existing.contains(where: { $0.id != entry?.id && $0.kind == kind.rawValue && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else {
            throw FormError.message("That name already exists in this list, possibly archived. Rename or restore the existing entry.")
        }
        if let entry { entry.name = name } else { context.insert(Classification(name: name, kind: kind.rawValue)) }
        try context.save()
    }
}
