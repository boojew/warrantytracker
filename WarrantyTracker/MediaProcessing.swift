import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreTransferable
import PDFKit

enum AttachmentRole: String, CaseIterable, Identifiable {
    case itemPhoto, receipt, serialNumber, extra, policy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .itemPhoto: "Item photo"
        case .receipt: "Receipt"
        case .serialNumber: "Serial number"
        case .extra: "Extra photo / document"
        case .policy: "Warranty document"
        }
    }
}

struct ReviewPage: Identifiable, Sendable {
    let id: UUID = UUID()
    let image: CGImage
    let pointSize: CGSize
    var redactions: [CGRect] = [] // Normalized coordinates, measured from the top left.
}

struct ReviewDocument: Identifiable, Sendable {
    let id: UUID = UUID()
    var pages: [ReviewPage]
    let isPDF: Bool
}

struct PreparedAttachment: Identifiable, Sendable {
    let id: UUID = UUID()
    var title: String
    var role: AttachmentRole
    let mediaType: String
    let content: Data
    let thumbnail: Data
    let pageCount: Int
}

enum MediaFiles {
    static let maxInputBytes = 30 * 1024 * 1024
    static func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readable in
            result = Result {
                let file = try FileHandle(forReadingFrom: readable)
                defer { try? file.close() }
                let data = try file.read(upToCount: maxInputBytes + 1) ?? Data()
                guard !data.isEmpty, data.count <= maxInputBytes else {
                    throw FormError.message("Choose a file smaller than 30 MB that is not empty.")
                }
                return data
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw FormError.message("The selected file could not be read. Download it to this device and try again.") }
        return try result.get()
    }
}

struct PickedPhoto: Transferable, Sendable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            PickedPhoto(data: try MediaFiles.read(received.file))
        }
    }
}

/// Decoding and rendering run away from the UI. An import is held in memory until review is saved.
actor MediaProcessor {
    static let shared = MediaProcessor()
    static let maxPages = 20
    static let maxImageSide = 4096
    static let maxPDFSide = 2400
    static let maxTotalPixels = 32_000_000

    func load(url: URL) throws -> ReviewDocument { try load(data: MediaFiles.read(url)) }

    func load(data: Data) throws -> ReviewDocument {
        guard !data.isEmpty, data.count <= MediaFiles.maxInputBytes else {
            throw FormError.message("Choose a file smaller than 30 MB that is not empty.")
        }
        if let pdf = PDFDocument(data: data) {
            guard !pdf.isEncrypted else { throw FormError.message("Password-protected PDFs are not supported. Import an unlocked copy.") }
            guard (1...Self.maxPages).contains(pdf.pageCount) else {
                throw FormError.message("Import a PDF with 1–20 pages. Split longer documents into smaller files.")
            }
            var pages: [ReviewPage] = []
            var pixels = 0
            for number in 1...pdf.pageCount {
                try Task.checkCancellation()
                guard let page = pdf.page(at: number - 1) else { throw FormError.message("A PDF page could not be read.") }
                let box = page.bounds(for: .cropBox)
                guard box.width.isFinite, box.height.isFinite, box.width > 0, box.height > 0 else {
                    throw FormError.message("This PDF has an invalid page size.")
                }
                let rotated = abs(page.rotation) % 180 == 90
                let size = rotated ? CGSize(width: box.height, height: box.width) : box.size
                let scale = min(2, CGFloat(Self.maxPDFSide) / max(size.width, size.height))
                let width = max(1, Int((size.width * scale).rounded()))
                let height = max(1, Int((size.height * scale).rounded()))
                pixels += width * height
                guard pixels <= Self.maxTotalPixels else {
                    throw FormError.message("This PDF is too large to review at once. Split it into smaller files.")
                }
                let context = try Self.bitmap(width: width, height: height)
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(rect)
                context.scaleBy(x: CGFloat(width) / size.width, y: CGFloat(height) / size.height)
                page.displaysAnnotations = true
                page.draw(with: .cropBox, to: context)
                guard let image = context.makeImage() else { throw FormError.message("Unable to display this PDF page.") }
                pages.append(ReviewPage(image: image, pointSize: size))
            }
            return ReviewDocument(pages: pages, isPDF: true)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.maxImageSide,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            throw FormError.message("Choose a single JPEG, PNG or HEIC image, or a PDF. Animated and multi-image files are not supported.")
        }
        return ReviewDocument(pages: [ReviewPage(image: image, pointSize: CGSize(width: image.width, height: image.height))], isPDF: false)
    }

    func prepare(_ document: ReviewDocument, title: String, role: AttachmentRole) throws -> PreparedAttachment {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw FormError.message("Enter a name for this attachment.") }
        guard !document.pages.isEmpty else { throw FormError.message("There are no pages to save.") }
        guard role != .itemPhoto || !document.isPDF else { throw FormError.message("Choose an image for the item photo.") }
        var firstImage: CGImage?
        let content: Data
        if document.isPDF {
            let data = NSMutableData()
            guard let consumer = CGDataConsumer(data: data), let pdf = CGContext(consumer: consumer, mediaBox: nil, nil) else {
                throw FormError.message("Unable to create a reviewed PDF.")
            }
            for page in document.pages {
                try Task.checkCancellation()
                let image = try Self.flatten(page)
                if firstImage == nil { firstImage = image }
                var box = CGRect(origin: .zero, size: page.pointSize)
                let boxData = Data(bytes: &box, count: MemoryLayout<CGRect>.size)
                pdf.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
                pdf.draw(image, in: box)
                pdf.endPDFPage()
            }
            pdf.closePDF()
            content = data as Data
        } else {
            let image = try Self.flatten(document.pages[0])
            firstImage = image
            content = try Self.jpeg(image)
        }
        guard content.count <= MediaFiles.maxInputBytes else {
            throw FormError.message("The reviewed copy exceeds 30 MB. Import fewer pages at a time.")
        }
        guard let firstImage else { throw FormError.message("Unable to create the preview.") }
        let thumbnail = try Self.jpeg(Self.resize(firstImage, maxSide: 256))
        return PreparedAttachment(title: title, role: role, mediaType: document.isPDF ? "pdf" : "image",
                                  content: content, thumbnail: thumbnail, pageCount: document.pages.count)
    }

    static func bitmap(width: Int, height: Int) throws -> CGContext {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw FormError.message("Not enough memory to review this file. Choose a smaller file.")
        }
        return context
    }

    static func flatten(_ page: ReviewPage) throws -> CGImage {
        let width = page.image.width, height = page.image.height
        let context = try bitmap(width: width, height: height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(bounds)
        context.draw(page.image, in: bounds)
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for redaction in page.redactions {
            let rect = redaction.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !rect.isNull, !rect.isEmpty else { continue }
            // Fill the actual pixels; do not save removable PDF annotations or image overlays.
            context.fill(CGRect(x: rect.minX * CGFloat(width), y: (1 - rect.maxY) * CGFloat(height),
                                width: rect.width * CGFloat(width), height: rect.height * CGFloat(height)).integral)
        }
        guard let image = context.makeImage() else { throw FormError.message("Unable to save the reviewed image.") }
        return image
    }

    static func resize(_ image: CGImage, maxSide: Int) throws -> CGImage {
        let scale = min(1, CGFloat(maxSide) / CGFloat(max(image.width, image.height)))
        let width = max(1, Int(CGFloat(image.width) * scale)), height = max(1, Int(CGFloat(image.height) * scale))
        let context = try bitmap(width: width, height: height)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let result = context.makeImage() else { throw FormError.message("Unable to create a preview.") }
        return result
    }

    static func jpeg(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw FormError.message("Unable to encode this image.")
        }
        // Fresh pixels only: no source EXIF, GPS, comments, filenames, or PDF text layers.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.94] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw FormError.message("Unable to finish saving the image.") }
        return data as Data
    }
}
