import Foundation
import SwiftData
import Testing
@testable import WarrantyTracker

@MainActor
struct SyncTests {
    @Test func localAndCloudUseTheSameStoreLocation() {
        let local = Persistence.configuration()
        let cloud = Persistence.configuration(sync: .privateCloud("iCloud.com.boojew.warrantytracker"))
        #expect(local.url == cloud.url)
        #expect(SyncMode.configured(isolated: true) == .local)
    }

    @Test func optionalDateCanBeAddedClearedAndCancelled() throws {
        let container = try Persistence.container(inMemory: true)
        let context = ModelContext(container)
        let item = Item(name: "Kobo"); context.insert(item)
        var draft = ItemDraft(); draft.name = item.name
        #expect(draft.purchaseDate == nil)
        try draft.apply(to: item)
        #expect(item.purchasedOn == nil)
        draft = ItemDraft(item: item)
        draft.purchaseDate = CalendarDay.decode("2026-09-28")
        #expect(item.purchasedOn == nil)
        try draft.apply(to: item)
        #expect(item.purchasedOn == "2026-09-28")
        draft.purchaseDate = nil
        try draft.apply(to: item)
        #expect(item.purchasedOn == nil)
    }

    @Test func backupKeepsV3RelationshipsAndExternalAssets() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "inventory.store")
        let payload = Data(repeating: 73, count: 2 * 1024 * 1024)
        try autoreleasepool {
            let schema = Schema(versionedSchema: WarrantySchemaV3.self)
            let config = ModelConfiguration("WarrantyTracker", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let item = WarrantySchemaV3.Item(name: "Existing TV")
            context.insert(item)
            let attachment = WarrantySchemaV3.Attachment()
            context.insert(attachment); attachment.item = item; attachment.content = payload
            item.mainPhotoID = attachment.id
            let preferences = WarrantySchemaV3.Preferences()
            preferences.currencyCode = "USD"; context.insert(preferences)
            try context.save()
        }
        try StoreBackup.beforeFirstCloudOpen(at: url)
        for path in [url, StoreBackup.destination(for: url)] {
            try autoreleasepool {
                let container = try Persistence.container(url: path)
                let context = ModelContext(container)
                let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
                #expect(item.name == "Existing TV")
                #expect(item.mainPhoto?.content == payload)
                let prefs = try #require(context.fetch(FetchDescriptor<Preferences>()).first)
                #expect(prefs.currencyCode == "USD")
                #expect(prefs.modifiedAt == Date(timeIntervalSince1970: 0))
            }
        }
        // A later launch must not replace the original backup with a newer/deleted inventory.
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            for item in try context.fetch(FetchDescriptor<Item>()) { context.delete(item) }
            try context.save()
        }
        try StoreBackup.beforeFirstCloudOpen(at: url)
        let backup = try Persistence.container(url: StoreBackup.destination(for: url))
        #expect(try ModelContext(backup).fetchCount(FetchDescriptor<Item>()) == 1)
    }

    @Test func simultaneousDefaultSeedsKeepLinksAndConvergeWithoutDeletingRecords() throws {
        let container = try Persistence.container(inMemory: true)
        let context = ModelContext(container)
        let older = Preferences(); older.currencyCode = "USD"; context.insert(older)
        let newer = Preferences(); newer.modifiedAt = Date(); newer.countryCode = "GB"; context.insert(newer)
        #expect(SyncReconciliation.currentPreferences([older, newer]) === newer)
        let first = Classification(name: "Home", kind: "location")
        let second = Classification(name: "House", kind: "location")
        second.seedKey = "seed:location:0"; second.modifiedAt = Date(); second.isArchived = true
        context.insert(first); context.insert(second)
        let tv = Item(name: "TV"); context.insert(tv); tv.location = first
        let watch = Item(name: "Watch"); context.insert(watch); watch.location = second
        try context.save()
        try SyncReconciliation.reconcileCatalog(in: context)
        #expect(first.name == "House" && first.isArchived)
        #expect(tv.location === first && watch.location === second)
        #expect(SyncReconciliation.visible([first, second]).count == 1)
        #expect(SyncReconciliation.visible([first, second], keeping: [second]).first === second)
        try Catalog.save(name: "Condo", kind: .location, entry: first, in: context)
        #expect(first.name == "Condo" && second.name == "Condo")
        try Catalog.setArchived(false, entry: second, in: context)
        #expect(!first.isArchived && !second.isArchived)
        #expect(try context.fetchCount(FetchDescriptor<Classification>()) == 2)
        try SyncReconciliation.reconcileCatalog(in: context)
        #expect(!context.hasChanges)
    }

    @Test func syncEventsDoNotClaimEverythingIsSyncedOrLoseOverlappingOperations() {
        var progress = SyncProgress()
        let first = UUID(), second = UUID(), now = Date()
        progress.receive(SyncEvent(id: first, activity: .upload, finishedAt: nil, succeeded: false, failure: nil))
        progress.receive(SyncEvent(id: second, activity: .download, finishedAt: nil, succeeded: false, failure: nil))
        progress.receive(SyncEvent(id: first, activity: .upload, finishedAt: now, succeeded: false, failure: "Offline"))
        #expect(progress.active.count == 1 && progress.lastUpload == nil)
        progress.receive(SyncEvent(id: second, activity: .download, finishedAt: now, succeeded: true, failure: nil))
        #expect(progress.failures[.upload] == "Offline")
        #expect(progress.lastDownload == now)
        progress.receive(SyncEvent(id: UUID(), activity: .upload, finishedAt: now, succeeded: true, failure: nil))
        #expect(progress.failures.isEmpty && progress.lastUpload == now && progress.active.isEmpty)
    }
}
