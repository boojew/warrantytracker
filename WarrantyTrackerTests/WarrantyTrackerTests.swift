import Foundation
import SwiftData
import Testing
@testable import WarrantyTracker

struct ValueTests {
    @Test func pricesRemainExactAndRejectPartialInput() throws {
        let english = Locale(identifier: "en_CA")
        #expect(try Money.parse("999.99", locale: english) == "999.99")
        #expect(try Money.parse("0.10", locale: english) == "0.1")
        #expect(try Money.parse("", locale: english) == nil)
        #expect(try Money.parse("19,95", locale: Locale(identifier: "fr_CA")) == "19.95")
        for invalid in ["-1", "19 dollars", "1,234.00", "1.2.3", "NaN", "999999999999999999999"] {
            #expect(throws: EntryError.self) { try Money.parse(invalid, locale: english) }
        }
    }

    @Test func calendarDaysSurviveTravelAndValidateLeapDays() throws {
        for zone in ["America/Toronto", "Pacific/Auckland", "America/Los_Angeles"] {
            let timeZone = try #require(TimeZone(identifier: zone))
            let date = try #require(CalendarDay.decode("2028-02-29", timeZone: timeZone))
            #expect(CalendarDay.encode(date, timeZone: timeZone) == "2028-02-29")
            #expect(CalendarDay.decode("2027-02-29", timeZone: timeZone) == nil)
        }
    }

    @Test func coverageIncludesEndDayAndMissingDateIsUnknown() {
        #expect(CoverageStatus.manufacturer(end: nil, today: "2026-09-27") == .unknown)
        #expect(CoverageStatus.manufacturer(end: "2026-09-27", today: "2026-09-27") == .recorded)
        #expect(CoverageStatus.manufacturer(end: "2026-09-26", today: "2026-09-27") == .expired)
    }
}

@MainActor
struct PersistenceTests {
    @Test func recordsAndWarrantySurviveReopeningDiskStore() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "test.store")
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            var draft = ItemDraft()
            draft.name = "Living room TV"
            draft.manufacturer = "Example Manufacturer"
            draft.retailer = "Costco"
            draft.price = Money.editable("999.99")
            draft.purchaseDate = CalendarDay.decode("2026-09-27")
            draft.hasWarrantyEnd = true
            draft.warrantyEnd = try #require(CalendarDay.decode("2028-09-27"))
            let item = Item(name: draft.name)
            context.insert(item)
            try draft.apply(to: item)
            try context.save()
        }
        try autoreleasepool {
            let reopened = try Persistence.container(url: url)
            let context = ModelContext(reopened)
            let items = try context.fetch(FetchDescriptor<Item>())
            #expect(items.count == 1)
            let item = try #require(items.first)
            #expect(item.name == "Living room TV")
            #expect(item.priceAmount == "999.99")
            #expect(item.countryCode == "CA")
            #expect(item.currencyCode == "CAD")
            #expect(item.purchasedOn == "2026-09-27")
            #expect(item.manufacturerCoverage?.endsOn == "2028-09-27")
            #expect(item.manufacturerCoverage?.item?.id == item.id)
            #expect(try context.fetchCount(FetchDescriptor<Coverage>()) == 1)
        }
    }

    @Test func editingDoesNotDuplicateCoverageAndDeletingCascades() throws {
        let container = try Persistence.container(inMemory: true)
        let context = ModelContext(container)
        let item = Item(name: "Kobo")
        context.insert(item)
        var draft = ItemDraft()
        draft.name = item.name
        try draft.apply(to: item)
        try context.save()
        draft = ItemDraft(item: item)
        draft.hasWarrantyEnd = true
        try draft.apply(to: item)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Coverage>()) == 1)
        draft.hasWarrantyEnd = false
        try draft.apply(to: item)
        try context.save()
        #expect(item.manufacturerCoverage?.endsOn == nil)
        #expect(item.manufacturerCoverage?.duration == "unknown")
        context.delete(item)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Coverage>()) == 0)
    }

    @Test func draftsDoNotChangeSavedItemsUntilApplied() throws {
        let item = Item(name: "Original")
        var draft = ItemDraft(item: item)
        draft.name = "Unsaved change"
        #expect(item.name == "Original")
        draft.purchaseDate = CalendarDay.decode("2026-09-27")
        draft.hasWarrantyEnd = true
        draft.warrantyEnd = try #require(CalendarDay.decode("2025-09-27"))
        // Editing an item no longer edits its separate coverage records.
        try draft.validate()
        var newDraft = ItemDraft()
        newDraft.name = "New item"
        newDraft.purchaseDate = draft.purchaseDate
        newDraft.hasWarrantyEnd = true
        newDraft.warrantyEnd = draft.warrantyEnd
        #expect(throws: EntryError.self) { try newDraft.validate() }
        #expect(item.name == "Original")
    }

    @Test func defaultsApplyOnlyToNewItems() throws {
        let settings = Preferences()
        settings.countryCode = "US"
        settings.currencyCode = "USD"
        let item = Item(name: "Canadian purchase")
        #expect(ItemDraft(defaults: settings).currencyCode == "USD")
        #expect(ItemDraft(item: item, defaults: settings).currencyCode == "CAD")
        #expect(ItemDraft(item: item, defaults: settings).countryCode == "CA")
    }
}

@MainActor
struct MilestoneTwoTests {
    private func cardDraft() -> CardDraft {
        var draft = CardDraft()
        draft.nickname = "Everyday"
        draft.bank = "Example Bank"
        draft.productName = "Example Privilege"
        draft.firstFour = "1234"
        draft.lastFour = "5678"
        return draft
    }

    @Test func migrationPreservesMilestoneOneRecords() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "migration.store")
        let id = UUID()
        try autoreleasepool {
            let schema = Schema(versionedSchema: WarrantySchemaV1.self)
            let config = ModelConfiguration("WarrantyTracker", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let item = WarrantySchemaV1.Item(name: "Original TV")
            item.id = id; item.priceAmount = "999.99"; item.retailer = "Costco"
            item.purchasedOn = "2026-09-01"; item.serialNumber = "ABC-123"; item.notes = "Keep receipt"
            let coverage = WarrantySchemaV1.Coverage()
            coverage.provider = "Example maker"; coverage.duration = "fixed"; coverage.endsOn = "2028-09-01"
            context.insert(item)
            item.coverages = [coverage]; coverage.item = item
            let defaults = WarrantySchemaV1.Preferences()
            defaults.countryCode = "US"; defaults.currencyCode = "USD"
            context.insert(defaults)
            try context.save()
        }
        for _ in 0..<2 {
            try autoreleasepool {
                let container = try Persistence.container(url: url)
                let context = ModelContext(container)
                let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
                #expect(item.id == id)
                #expect(item.name == "Original TV" && item.priceAmount == "999.99")
                #expect(item.retailer == "Costco" && item.purchasedOn == "2026-09-01")
                #expect(item.serialNumber == "ABC-123" && item.notes == "Keep receipt")
                #expect(item.countryCode == "CA" && item.currencyCode == "CAD")
                #expect(item.manufacturerCoverage?.endsOn == "2028-09-01")
                #expect(item.manufacturerCoverage?.provider == "Example maker")
                #expect(item.manufacturerCoverage?.item?.id == id)
                let defaults = try #require(context.fetch(FetchDescriptor<Preferences>()).first)
                #expect(defaults.currencyCode == "USD")
                try Catalog.initialize(in: context)
                #expect(defaults.currencyCode == "USD")
                try context.save()
            }
        }
    }

    @Test func coverageStatesRespectIndependentInclusiveDates() throws {
        let coverage = Coverage()
        #expect(CoverageStatus.status(of: coverage, today: "2026-09-28") == .unknown)
        coverage.duration = "ongoing"
        #expect(CoverageStatus.status(of: coverage, today: "2026-09-28") == .ongoing)
        coverage.cancelledOn = "2026-09-28"
        #expect(CoverageStatus.status(of: coverage, today: "2026-09-28") == .ending)
        #expect(CoverageStatus.status(of: coverage, today: "2026-09-29") == .cancelled)
        coverage.cancelledOn = nil; coverage.startsOn = "2026-10-01"
        #expect(CoverageStatus.status(of: coverage, today: "2026-09-28") == .upcoming)
        var draft = CoverageDraft(coverage: coverage)
        draft.duration = .fixed
        draft.end = try #require(CalendarDay.decode("2026-09-01"))
        #expect(throws: FormError.self) { try draft.validate() }
        draft.end = try #require(CalendarDay.decode("2027-10-01"))
        draft.isCancelled = true
        draft.cancellationEnd = try #require(CalendarDay.decode("2028-10-01"))
        #expect(throws: FormError.self) { try draft.validate() }
        draft.cancellationEnd = try #require(CalendarDay.decode("2027-01-01"))
        try draft.apply(to: coverage)
        #expect(coverage.effectiveEnd == "2027-01-01")
        #expect(coverage.endsOn == "2027-10-01")
    }

    @Test func replacementCardsAndMultipleCoveragesSurviveRelaunch() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "cards.store")
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            let account = CardAccount(nickname: "Everyday")
            context.insert(account)
            var card = cardDraft()
            let original = try card.apply(to: account)
            let item = Item(name: "Pool pump")
            context.insert(item)
            var purchase = ItemDraft()
            purchase.name = "Pool pump"; purchase.retailer = "Club Piscine"; purchase.purchaseCard = original
            try purchase.apply(to: item)
            let extra = Coverage()
            context.insert(extra); extra.item = item
            var draft = CoverageDraft(item: item)
            draft.kind = .creditCard; draft.name = "Card extension"; draft.terms = "Doubles up to two years"
            draft.duration = .fixed; draft.end = try #require(CalendarDay.decode("2029-01-01"))
            try draft.apply(to: extra)
            card.lastFour = "9012"
            let replacement = try card.apply(to: account)
            #expect(replacement.id != original.id)
            let watch = Item(name: "Apple Watch")
            context.insert(watch); watch.purchaseCard = replacement
            let monthly = Coverage()
            context.insert(monthly); monthly.item = watch; monthly.name = "AppleCare+"; monthly.duration = "ongoing"
            var edit = ItemDraft(item: item)
            edit.manufacturer = "New spelling"; edit.hasWarrantyEnd = true
            try edit.apply(to: item)
            #expect(extra.endsOn == "2029-01-01" && extra.terms == "Doubles up to two years")
            card.nickname = "Renamed"
            #expect(try card.apply(to: account).id == replacement.id)
            #expect(account.orderedVersions.count == 2)
            account.isArchived = true
            try context.save()
        }
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            let account = try #require(context.fetch(FetchDescriptor<CardAccount>()).first)
            #expect(account.isArchived && account.nickname == "Renamed")
            #expect(account.purchases.count == 2)
            #expect(account.currentVersion?.lastFour == "9012")
            let pump = try #require(account.purchases.first { $0.name == "Pool pump" })
            #expect(pump.purchaseCard?.lastFour == "5678")
            #expect(pump.orderedCoverages.count == 2)
            let cardCoverage = try #require(pump.orderedCoverages.first { $0.kind == "creditCard" })
            #expect(cardCoverage.cardVersion?.id == pump.purchaseCard?.id)
            #expect(cardCoverage.terms == "Doubles up to two years")
            #expect(InventorySearch.matches(pump, query: "5678", field: .card))
            #expect(!InventorySearch.matches(pump, query: "9012", field: .card))
            context.delete(pump)
            try context.save()
            #expect(try context.fetchCount(FetchDescriptor<CardVersion>()) == 2)
            #expect(try context.fetchCount(FetchDescriptor<Coverage>()) == 1)
            #expect(account.purchases.count == 1)
        }
    }

    @Test func cardValidationNeverAcceptsFullNumbersOrSecurityCodes() throws {
        var draft = cardDraft()
        try draft.validate()
        for invalid in ["123", "12345", "1234567890123456", "１２３４", "12 3"] {
            draft.firstFour = invalid
            #expect(throws: FormError.self) { try draft.validate() }
        }
        draft = cardDraft(); draft.nickname = "1234 5678 9012 3456"
        #expect(throws: FormError.self) { try draft.validate() }
        draft = cardDraft(); draft.lastFour = "123"
        #expect(throws: FormError.self) { try draft.validate() }
    }

    @Test func catalogsAndScopedSearchPreserveLinks() throws {
        let container = try Persistence.container(inMemory: true)
        let context = ModelContext(container)
        try Catalog.initialize(in: context)
        let count = try context.fetchCount(FetchDescriptor<Classification>())
        try Catalog.initialize(in: context)
        #expect(try context.fetchCount(FetchDescriptor<Classification>()) == count)
        let entries = try context.fetch(FetchDescriptor<Classification>())
        let category = try #require(entries.first { $0.kind == "category" })
        let tag = try #require(entries.first { $0.kind == "tag" })
        let location = try #require(entries.first { $0.kind == "location" && $0.name == "Home" })
        let item = Item(name: "Home speaker")
        item.retailer = "Best Buy"; item.notes = "Matter setup"; item.priceAmount = "99.99"
        context.insert(item)
        item.category = category; item.tags = [tag]; item.location = location
        try context.save()
        #expect(InventorySearch.matches(item, query: "Home", field: .all))
        #expect(!InventorySearch.matches(item, query: "Home", field: .store))
        item.retailer = "Home Depot"
        #expect(InventorySearch.matches(item, query: "home", field: .store))
        #expect(InventorySearch.matches(item, query: "99.99", field: .price))
        #expect(InventorySearch.matches(item, query: "Matter", field: .notes))
        try Catalog.save(name: "Living room", kind: .location, entry: location, in: context)
        location.isArchived = true
        try context.save()
        #expect(item.location?.name == "Living room")
        #expect(InventorySearch.matches(item, query: "Living", field: .location))
        #expect(throws: FormError.self) { try Catalog.save(name: "living room", kind: .location, entry: nil, in: context) }
        context.delete(item)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Classification>()) == count)
        #expect(location.locationItems?.isEmpty == true)
    }
}
