import Foundation
import SwiftData

enum WarrantySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Item.self, Coverage.self, Preferences.self] }

    @Model
    final class Item {
        var id: UUID = UUID()
        var name: String = ""
        var manufacturer: String = ""
        var retailer: String = ""
        var countryCode: String = "CA"
        var currencyCode: String = "CAD"
        // Canonical decimal text avoids binary floating-point rounding and transformables.
        var priceAmount: String?
        var purchasedOn: String?
        var serialNumber: String = ""
        var notes: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \Coverage.item)
        var coverages: [Coverage]? = []

        init(name: String) { self.name = name }

        var manufacturerCoverage: Coverage? {
            coverages?.first { $0.kind == "manufacturer" }
        }
    }

    @Model
    final class Coverage {
        var id: UUID = UUID()
        var kind: String = "manufacturer"
        var provider: String = ""
        // A missing end date is unknown, not an ongoing subscription.
        var duration: String = "unknown"
        var startsOn: String?
        var endsOn: String?
        var notes: String = ""
        var source: String = "manual"
        var item: Item?

        init() {}
    }

    @Model
    final class Preferences {
        var id: UUID = UUID()
        var countryCode: String = "CA"
        var currencyCode: String = "CAD"
        init() {}
    }
}

typealias Item = WarrantySchemaV1.Item
typealias Coverage = WarrantySchemaV1.Coverage
typealias Preferences = WarrantySchemaV1.Preferences

enum WarrantyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WarrantySchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    static func container(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: WarrantySchemaV1.self)
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("WarrantyTracker", schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration("WarrantyTracker", schema: schema,
                                               isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: WarrantyMigrationPlan.self,
                                  configurations: [configuration])
    }
}
