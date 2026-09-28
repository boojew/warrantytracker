import Foundation
import SwiftData

@MainActor
enum AttachmentOwner {
    case item(Item)
    case coverage(Coverage)

    var attachments: [Attachment] {
        let values: [Attachment]
        switch self {
        case .item(let item): values = item.attachments ?? []
        case .coverage(let coverage): values = coverage.attachments ?? []
        }
        return values.sorted { $0.createdAt < $1.createdAt }
    }
    var item: Item? {
        switch self {
        case .item(let item): item
        case .coverage(let coverage): coverage.item
        }
    }
    var isItem: Bool { if case .item = self { true } else { false } }
    var defaultRole: AttachmentRole { isItem ? .extra : .policy }
}

@MainActor
enum AttachmentStore {
    @discardableResult
    static func insert(_ prepared: PreparedAttachment, owner: AttachmentOwner, in context: ModelContext) -> Attachment {
        let attachment = Attachment()
        context.insert(attachment)
        update(attachment, from: prepared)
        switch owner {
        case .item(let item):
            attachment.item = item
            if prepared.role == .itemPhoto { item.mainPhotoID = attachment.id }
        case .coverage(let coverage): attachment.coverage = coverage
        }
        owner.item?.updatedAt = Date()
        return attachment
    }

    static func update(_ attachment: Attachment, from prepared: PreparedAttachment) {
        attachment.title = prepared.title
        attachment.role = prepared.role.rawValue
        attachment.mediaType = prepared.mediaType
        attachment.content = prepared.content
        attachment.thumbnail = prepared.thumbnail
        attachment.pageCount = prepared.pageCount
        attachment.reviewedAt = Date()
    }

    static func delete(_ attachment: Attachment, in context: ModelContext) throws {
        if let item = attachment.item, item.mainPhotoID == attachment.id { item.mainPhotoID = nil }
        (attachment.item ?? attachment.coverage?.item)?.updatedAt = Date()
        context.delete(attachment)
        try context.save()
    }
}
