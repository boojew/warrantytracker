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
            draft.hasPurchaseDate = true
            draft.purchaseDate = try #require(CalendarDay.decode("2026-09-27"))
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
        var draft = ItemDraft(item: item)
        try draft.apply(to: item)
        try context.save()
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
        draft.hasPurchaseDate = true
        draft.purchaseDate = try #require(CalendarDay.decode("2026-09-27"))
        draft.hasWarrantyEnd = true
        draft.warrantyEnd = try #require(CalendarDay.decode("2025-09-27"))
        #expect(throws: EntryError.self) { try draft.validate() }
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
