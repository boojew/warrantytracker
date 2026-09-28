import Foundation
import SwiftData

enum WarrantySchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Item.self, Coverage.self, Preferences.self, CardAccount.self, CardVersion.self, Classification.self, Attachment.self]
    }

    @Model
    final class Item {
        var id: UUID = UUID()
        var name: String = ""
        var manufacturer: String = ""
        var retailer: String = ""
        var countryCode: String = "CA"
        var currencyCode: String = "CAD"
        var priceAmount: String?
        var purchasedOn: String?
        var serialNumber: String = ""
        var notes: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \Coverage.item)
        var coverages: [Coverage]? = []
        @Relationship(deleteRule: .cascade, inverse: \Attachment.item)
        var attachments: [Attachment]? = []
        var mainPhotoID: UUID?
        var purchaseCard: CardVersion?
        var category: Classification?
        var location: Classification?
        var tags: [Classification]? = []

        init(name: String) { self.name = name }
        var mainPhoto: Attachment? { attachments?.first { $0.id == mainPhotoID && $0.mediaType == "image" } }
        var manufacturerCoverage: Coverage? { orderedCoverages.first { $0.kind == "manufacturer" } }
        var orderedCoverages: [Coverage] {
            (coverages ?? []).sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.createdAt < $1.createdAt
            }
        }
    }

    @Model
    final class Coverage {
        var id: UUID = UUID()
        var kind: String = "manufacturer"
        var provider: String = ""
        var duration: String = "unknown"
        var startsOn: String?
        var endsOn: String?
        var notes: String = ""
        var source: String = "manual"
        var item: Item?
        var name: String = ""
        var terms: String = ""
        var exclusions: String = ""
        // The final covered day, not the date a cancellation was requested.
        var cancelledOn: String?
        var createdAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \Attachment.coverage)
        var attachments: [Attachment]? = []
        var cardVersion: CardVersion?

        init() {}
        var title: String { name.isEmpty ? (CoverageKind(rawValue: kind)?.label ?? "Warranty") : name }
        var effectiveEnd: String? { [endsOn, cancelledOn].compactMap { $0 }.min() }
    }

    @Model
    final class Preferences {
        var id: UUID = UUID()
        var countryCode: String = "CA"
        var currencyCode: String = "CAD"
        var listsInitialized: Bool = false
        init() {}
    }

    @Model
    final class CardAccount {
        var id: UUID = UUID()
        var nickname: String = ""
        var isArchived: Bool = false
        var createdAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \CardVersion.account)
        var versions: [CardVersion]? = []

        init(nickname: String) { self.nickname = nickname }
        var orderedVersions: [CardVersion] {
            (versions ?? []).sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.createdAt > $1.createdAt
            }
        }
        var currentVersion: CardVersion? { orderedVersions.first }
        var purchases: [Item] {
            var seen = Set<UUID>()
            return orderedVersions.flatMap { $0.purchases ?? [] }
                .filter { seen.insert($0.id).inserted }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    @Model
    final class CardVersion {
        var id: UUID = UUID()
        var bank: String = ""
        var network: String = ""
        var productName: String = ""
        var firstFour: String = ""
        var lastFour: String = ""
        var createdAt: Date = Date()
        var account: CardAccount?
        @Relationship(deleteRule: .nullify, inverse: \Item.purchaseCard)
        var purchases: [Item]? = []
        @Relationship(deleteRule: .nullify, inverse: \Coverage.cardVersion)
        var coverages: [Coverage]? = []

        init() {}
        var maskedNumber: String { "\(firstFour) •••• \(lastFour)" }
        var label: String {
            "\(account?.nickname ?? productName) — \(productName) — \(maskedNumber)"
        }
    }

    @Model
    final class Classification {
        var id: UUID = UUID()
        var kind: String = "tag"
        var name: String = ""
        var isArchived: Bool = false
        @Relationship(deleteRule: .nullify, inverse: \Item.category)
        var categoryItems: [Item]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.location)
        var locationItems: [Item]? = []
        @Relationship(deleteRule: .nullify, inverse: \Item.tags)
        var taggedItems: [Item]? = []

        init(name: String, kind: String) { self.name = name; self.kind = kind }
    }

    @Model
    final class Attachment {
        var id: UUID = UUID()
        var title: String = ""
        var role: String = "extra"
        var mediaType: String = "image"
        var pageCount: Int = 1
        var createdAt: Date = Date()
        var reviewedAt: Date = Date()
        // Only a flattened, user-reviewed copy is stored. Never store an import URL or original data.
        @Attribute(.externalStorage) var content: Data?
        var thumbnail: Data?
        var item: Item?
        var coverage: Coverage?

        init() {}
    }

}
