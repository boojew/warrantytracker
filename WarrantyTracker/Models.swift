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

// Keep V1 frozen: existing installations need this exact schema to migrate.
typealias Item = WarrantySchemaV4.Item
typealias Coverage = WarrantySchemaV4.Coverage
typealias Preferences = WarrantySchemaV4.Preferences
typealias CardAccount = WarrantySchemaV4.CardAccount
typealias CardVersion = WarrantySchemaV4.CardVersion
typealias Classification = WarrantySchemaV4.Classification

typealias Attachment = WarrantySchemaV4.Attachment

enum WarrantyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WarrantySchemaV1.self, WarrantySchemaV2.self, WarrantySchemaV3.self, WarrantySchemaV4.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: WarrantySchemaV1.self, toVersion: WarrantySchemaV2.self),
         .lightweight(fromVersion: WarrantySchemaV2.self, toVersion: WarrantySchemaV3.self),
         .lightweight(fromVersion: WarrantySchemaV3.self, toVersion: WarrantySchemaV4.self)]
    }
}

enum Persistence {
    static func configuration(url: URL? = nil, inMemory: Bool = false,
                              sync: SyncMode = .local) -> ModelConfiguration {
        let schema = Schema(versionedSchema: WarrantySchemaV4.self)
        // Keeping the original configuration name and URL preserves existing stores and assets.
        let cloud: ModelConfiguration.CloudKitDatabase
        if case .privateCloud(let identifier) = sync, !inMemory { cloud = .private(identifier) }
        else { cloud = .none }
        if let url {
            return ModelConfiguration("WarrantyTracker", schema: schema, url: url, cloudKitDatabase: cloud)
        }
        return ModelConfiguration("WarrantyTracker", schema: schema, isStoredInMemoryOnly: inMemory,
                                  cloudKitDatabase: cloud)
    }

    static func container(url: URL? = nil, inMemory: Bool = false, sync: SyncMode = .local) throws -> ModelContainer {
        let configuration = configuration(url: url, inMemory: inMemory, sync: sync)
        if sync.isEnabled && !inMemory { try StoreBackup.beforeFirstCloudOpen(at: configuration.url) }
        return try ModelContainer(for: Schema(versionedSchema: WarrantySchemaV4.self),
                                  migrationPlan: WarrantyMigrationPlan.self, configurations: [configuration])
    }
}
