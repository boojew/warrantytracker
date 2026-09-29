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
        try SyncReconciliation.reconcileCatalog(in: context)
        let allSettings = try context.fetch(FetchDescriptor<Preferences>())
        let settings = SyncReconciliation.currentPreferences(allSettings) ?? Preferences()
        guard !allSettings.contains(where: { $0.listsInitialized }) else { return }
        if settings.modelContext == nil { context.insert(settings) }
        let existing = try context.fetch(FetchDescriptor<Classification>())
        for kind in CatalogKind.allCases {
            for name in kind.defaults where !existing.contains(where: { $0.kind == kind.rawValue && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                let entry = Classification(name: name, kind: kind.rawValue)
                entry.seedKey = "seed:\(kind.rawValue):\(kind.defaults.firstIndex(of: name)!)"
                context.insert(entry)
            }
        }
        settings.listsInitialized = true
        try context.save()
    }

    static func setArchived(_ value: Bool, entry: Classification, in context: ModelContext) throws {
        let peers = try context.fetch(FetchDescriptor<Classification>()).filter { SyncReconciliation.key($0) == SyncReconciliation.key(entry) }
        let timestamp = Date()
        for peer in peers { peer.isArchived = value; peer.modifiedAt = timestamp }
        try context.save()
    }

    static func save(name: String, kind: CatalogKind, entry: Classification?, in context: ModelContext) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw FormError.message("Enter a name.") }
        let existing = try context.fetch(FetchDescriptor<Classification>())
        guard !existing.contains(where: { (entry == nil || SyncReconciliation.key($0) != SyncReconciliation.key(entry!)) && $0.kind == kind.rawValue && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else {
            throw FormError.message("That name already exists in this list, possibly archived. Rename or restore the existing entry.")
        }
        let timestamp = Date()
        if let entry {
            let peers = existing.filter { SyncReconciliation.key($0) == SyncReconciliation.key(entry) }
            for peer in peers { peer.name = name; peer.modifiedAt = timestamp }
        } else {
            let entry = Classification(name: name, kind: kind.rawValue)
            entry.modifiedAt = timestamp
            context.insert(entry)
        }
        try context.save()
    }
}
