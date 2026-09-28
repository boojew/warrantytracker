import Foundation
import SwiftData
import Testing
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import PDFKit
@testable import WarrantyTracker

struct AttachmentProcessingTests {
    static func sampleImage() throws -> CGImage {
        let context = try MediaProcessor.bitmap(width: 200, height: 300)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
        context.setFillColor(CGColor(red: 0, green: 0.6, blue: 0, alpha: 1))
        context.fill(CGRect(x: 120, y: 20, width: 50, height: 50))
        return try #require(context.makeImage())
    }

    static func samplePDF(pages: Int = 2) throws -> Data {
        let data = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: data))
        var box = CGRect(x: 0, y: 0, width: 200, height: 300)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(box)
            let text = NSAttributedString(string: "PRIVATE RECEIPT TEXT", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 12, nil)
            ])
            context.textPosition = CGPoint(x: 10, y: 240)
            CTLineDraw(CTLineCreateWithAttributedString(text), context)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    static func brightness(_ image: CGImage, x: Int, y: Int) throws -> Int {
        let context = try MediaProcessor.bitmap(width: image.width, height: image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = y * context.bytesPerRow + x * 4
        return (Int(bytes[offset]) + Int(bytes[offset + 1]) + Int(bytes[offset + 2])) / 3
    }

    @Test func redactionsArePixelsAndMetadataIsNotCopied() async throws {
        let image = try Self.sampleImage()
        let raw = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(raw, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 45.5,
            kCGImagePropertyGPSLatitudeRef: "N"], kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFArtist: "Private source"]] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        var document = try await MediaProcessor.shared.load(data: raw as Data)
        document.pages[0].redactions = [CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.25)]
        let prepared = try await MediaProcessor.shared.prepare(document, title: "Receipt", role: .receipt)
        let source = try #require(CGImageSourceCreateWithData(prepared.content as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
        #expect(properties[kCGImagePropertyGPSDictionary as String] == nil)
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        #expect(tiff?[kCGImagePropertyTIFFArtist as String] == nil)
        let reopened = try await MediaProcessor.shared.load(data: prepared.content)
        let savedImage = try #require(reopened.pages.first?.image)
        #expect(try Self.brightness(savedImage, x: 40, y: 60) < 15)
        #expect(try Self.brightness(savedImage, x: 40, y: 230) > 240)
        #expect(reopened.pages[0].redactions.isEmpty) // No removable overlay remains.
        let thumb = try #require(CGImageSourceCreateWithData(prepared.thumbnail as CFData, nil))
        let thumbImage = try #require(CGImageSourceCreateImageAtIndex(thumb, 0, nil))
        #expect(max(thumbImage.width, thumbImage.height) <= 256)
        #expect(try Self.brightness(thumbImage, x: 34, y: 51) < 15)
    }

    @Test func pdfPagesAreFlattenedWithNoSelectableOriginalText() async throws {
        let original = try Self.samplePDF()
        #expect(PDFDocument(data: original)?.string?.contains("PRIVATE RECEIPT TEXT") == true)
        var review = try await MediaProcessor.shared.load(data: original)
        #expect(review.pages.count == 2)
        review.pages[0].redactions = [CGRect(x: 0, y: 0, width: 1, height: 0.5)]
        let result = try await MediaProcessor.shared.prepare(review, title: "Warranty", role: .policy)
        let pdf = try #require(PDFDocument(data: result.content))
        #expect(pdf.pageCount == 2)
        #expect((pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(pdf.page(at: 0)?.annotations.isEmpty == true)
        let reopened = try await MediaProcessor.shared.load(data: result.content)
        #expect(try Self.brightness(reopened.pages[0].image, x: 20, y: 20) < 15)
        #expect(try Self.brightness(reopened.pages[1].image, x: 20, y: 20) > 240)
    }

    @Test func rotatedPDFAndAnnotationsRemainVisible() async throws {
        let pdf = try #require(PDFDocument(data: Self.samplePDF(pages: 1)))
        let page = try #require(pdf.page(at: 0))
        let annotation = PDFAnnotation(bounds: CGRect(x: 20, y: 20, width: 50, height: 50), forType: .square, withProperties: nil)
        annotation.interiorColor = .black
        annotation.color = .black
        page.addAnnotation(annotation)
        let first = try await MediaProcessor.shared.load(data: #require(pdf.dataRepresentation()))
        #expect(try Self.brightness(first.pages[0].image, x: 80, y: 520) < 15)
        page.rotation = 90
        let rotated = try await MediaProcessor.shared.load(data: #require(pdf.dataRepresentation()))
        #expect(rotated.pages[0].image.width == 600)
        #expect(rotated.pages[0].image.height == 400)
        #expect(try Self.brightness(rotated.pages[0].image, x: 80, y: 80) < 15)
    }

    @Test func imageOrientationIsNormalizedBeforeReview() async throws {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try Self.sampleImage(), [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let review = try await MediaProcessor.shared.load(data: data as Data)
        #expect(review.pages[0].image.width == 300)
        #expect(review.pages[0].image.height == 200)
    }

    @Test func unsupportedEmptyOversizedAndLongInputsAreRejected() async throws {
        for data in [Data(), Data("not an image".utf8), Data(repeating: 0, count: MediaFiles.maxInputBytes + 1)] {
            await #expect(throws: FormError.self) { try await MediaProcessor.shared.load(data: data) }
        }
        let long = try Self.samplePDF(pages: 21)
        await #expect(throws: FormError.self) { try await MediaProcessor.shared.load(data: long) }
        let document = try await MediaProcessor.shared.load(data: Self.samplePDF())
        await #expect(throws: FormError.self) { try await MediaProcessor.shared.prepare(document, title: "", role: .receipt) }
        await #expect(throws: FormError.self) { try await MediaProcessor.shared.prepare(document, title: "Photo", role: .itemPhoto) }
    }
}

@MainActor
struct AttachmentPersistenceTests {
    @Test func v2MigrationKeepsCardsTermsAndAttachmentsSurviveReopening() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "v2.store")
        let id = UUID()
        try autoreleasepool {
            let schema = Schema(versionedSchema: WarrantySchemaV2.self)
            let config = ModelConfiguration("WarrantyTracker", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let item = WarrantySchemaV2.Item(name: "Watch")
            item.id = id
            context.insert(item)
            let coverage = WarrantySchemaV2.Coverage()
            coverage.duration = "ongoing"; coverage.name = "Monthly plan"; coverage.terms = "Recorded original terms"
            item.coverages = [coverage]; coverage.item = item
            let account = WarrantySchemaV2.CardAccount(nickname: "Everyday")
            let version = WarrantySchemaV2.CardVersion()
            context.insert(account)
            version.firstFour = "1234"; version.lastFour = "5678"; account.versions = [version]; version.account = account
            item.purchaseCard = version; coverage.cardVersion = version
            let tag = WarrantySchemaV2.Classification(name: "Keep", kind: "tag")
            context.insert(tag); item.tags = [tag]
            try context.save()
        }
        let imageData = try MediaProcessor.jpeg(AttachmentProcessingTests.sampleImage())
        let document = try await MediaProcessor.shared.load(data: imageData)
        let photo = try await MediaProcessor.shared.prepare(document, title: "Watch photo", role: .itemPhoto)
        let pdf = try await MediaProcessor.shared.load(data: AttachmentProcessingTests.samplePDF())
        let policy = try await MediaProcessor.shared.prepare(pdf, title: "Plan document", role: .policy)
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
            #expect(item.id == id && item.purchaseCard?.lastFour == "5678")
            #expect(item.tags?.first?.name == "Keep")
            #expect(item.orderedCoverages.first?.terms == "Recorded original terms")
            let coverage = try #require(item.orderedCoverages.first)
            #expect(coverage.cardVersion?.id == item.purchaseCard?.id)
            AttachmentStore.insert(photo, owner: .item(item), in: context)
            for index in 1...5 {
                var extra = photo; extra.title = "Extra \(index)"; extra.role = .extra
                AttachmentStore.insert(extra, owner: .item(item), in: context)
            }
            AttachmentStore.insert(policy, owner: .coverage(coverage), in: context)
            try context.save()
        }
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
            #expect(item.attachments?.count == 6)
            #expect(item.mainPhoto?.content == photo.content)
            #expect(item.mainPhoto?.thumbnail == photo.thumbnail)
            #expect(item.orderedCoverages.first?.attachments?.first?.content == policy.content)
            #expect(InventorySearch.matches(item, query: "Plan document", field: .attachments))
            let main = try #require(item.mainPhoto)
            try AttachmentStore.delete(main, in: context)
            #expect(item.mainPhotoID == nil)
            #expect(item.attachments?.count == 5)
            context.delete(try #require(item.orderedCoverages.first))
            try context.save()
            #expect(try context.fetchCount(FetchDescriptor<WarrantyTracker.Attachment>()) == 5)
            context.delete(item)
            try context.save()
        }
        try autoreleasepool {
            let container = try Persistence.container(url: url)
            let context = ModelContext(container)
            #expect(try context.fetchCount(FetchDescriptor<WarrantyTracker.Attachment>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<CardAccount>()) == 1)
        }
    }
}
