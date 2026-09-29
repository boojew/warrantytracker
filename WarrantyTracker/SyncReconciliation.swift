import Foundation
import SwiftData

@MainActor
enum SyncReconciliation {
    static func currentPreferences(_ values: [Preferences]) -> Preferences? {
        values.sorted {
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
            // Before V4, customized defaults had no edit timestamp. Prefer them over a fresh seed.
            let leftCustomized = $0.countryCode != "CA" || $0.currencyCode != "CAD"
            let rightCustomized = $1.countryCode != "CA" || $1.currencyCode != "CAD"
            if leftCustomized != rightCustomized { return leftCustomized }
            return $0.id.uuidString < $1.id.uuidString
        }.first
    }

    static func key(_ entry: Classification) -> String {
        entry.seedKey ?? "custom:\(entry.kind):\(entry.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")))"
    }

    /// Keep every record and relationship. Duplicate seeds can arrive in separate CloudKit imports;
    /// deleting them while their relationships are still arriving could lose purchase classifications.
    static func reconcileCatalog(in context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<Classification>())
        for entry in entries where entry.seedKey == nil {
            if let kind = CatalogKind(rawValue: entry.kind), let index = kind.defaults.firstIndex(of: entry.name) {
                entry.seedKey = "seed:\(kind.rawValue):\(index)"
            }
        }
        for group in Dictionary(grouping: entries, by: key).values where group.count > 1 {
            let winner = group.sorted(by: preferred).first!
            for entry in group where entry !== winner {
                if entry.name != winner.name { entry.name = winner.name }
                if entry.isArchived != winner.isArchived { entry.isArchived = winner.isArchived }
                if entry.modifiedAt != winner.modifiedAt { entry.modifiedAt = winner.modifiedAt }
            }
        }
        if context.hasChanges { try context.save() }
    }

    static func visible(_ entries: [Classification], keeping selected: [Classification] = []) -> [Classification] {
        Dictionary(grouping: entries, by: key).values.compactMap { group in
            group.filter { selected.contains($0) }.sorted(by: preferred).first ?? group.sorted(by: preferred).first
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func preferred(_ left: Classification, _ right: Classification) -> Bool {
        if left.modifiedAt != right.modifiedAt { return left.modifiedAt > right.modifiedAt }
        if left.isArchived != right.isArchived { return left.isArchived }
        return left.id.uuidString < right.id.uuidString
    }
}
