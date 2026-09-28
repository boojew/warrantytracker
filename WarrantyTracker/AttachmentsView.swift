import SwiftUI
import SwiftData
import ImageIO
import PDFKit

struct AttachmentsView: View {
    @Environment(\.modelContext) private var context
    let owner: AttachmentOwner
    @State private var importing = false

    var body: some View {
        List {
            if owner.attachments.isEmpty {
                Text(owner.isItem ? "Add an item photo, receipt, serial-number photo, or extra images and PDFs." : "Keep this warranty's policy documents and photos together.")
                    .foregroundStyle(.secondary)
            }
            ForEach(owner.attachments) { attachment in
                NavigationLink { AttachmentDetailView(attachment: attachment) } label: {
                    HStack(spacing: 12) {
                        AttachmentThumbnail(data: attachment.thumbnail, symbol: attachment.mediaType == "pdf" ? "doc" : "photo")
                            .frame(width: 60, height: 60).clipped()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(attachment.title).font(.headline)
                            Text(AttachmentRole(rawValue: attachment.role)?.label ?? "Attachment").font(.caption)
                            Text(attachment.mediaType == "pdf" ? "PDF · \(attachment.pageCount) pages" : "Image")
                                .font(.caption).foregroundStyle(.secondary)
                            if attachment.item?.mainPhotoID == attachment.id { Text("Main photo").font(.caption).foregroundStyle(.teal) }
                        }
                    }
                }
            }
            Button("Add Attachment", systemImage: "plus") { importing = true }
                .accessibilityIdentifier("addAttachment")
        }
        .navigationTitle("Photos & Documents")
        .sheet(isPresented: $importing) {
            AttachmentImportView(defaultRole: owner.defaultRole, allowsItemPhoto: owner.isItem) { prepared in
                do {
                    AttachmentStore.insert(prepared, owner: owner, in: context)
                    try context.save()
                } catch { context.rollback(); throw error }
            }
        }
    }
}

struct AttachmentThumbnail: View {
    let data: Data?
    var symbol = "shippingbox.fill"
    var body: some View {
        Group {
            if let data, let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                Image(systemName: symbol).resizable().scaledToFit().padding(12).foregroundStyle(.teal)
                    .background(.teal.opacity(0.1))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
    }
}

struct AttachmentDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let attachment: Attachment
    @State private var confirmingDelete = false
    @State private var editing = false
    @State private var error: String?
    @State private var review: ReviewDocument?
    @State private var preparing = false

    private var preview: some View {
        VStack(spacing: 12) {
            if let data = attachment.content {
                SavedMediaView(data: data, isPDF: attachment.mediaType == "pdf")
            } else {
                ContentUnavailableView("Attachment unavailable", systemImage: "doc.badge.ellipsis",
                                       description: Text("The attachment data could not be loaded."))
            }
            HStack {
                Text(AttachmentRole(rawValue: attachment.role)?.label ?? "Attachment").foregroundStyle(.secondary)
                Spacer()
                if attachment.item?.mainPhotoID == attachment.id { Label("Main photo", systemImage: "checkmark.circle").foregroundStyle(.teal) }
            }.font(.caption).padding(.horizontal)
            if let item = attachment.item, attachment.mediaType == "image", item.mainPhotoID != attachment.id {
                Button("Use as Main Photo") {
                    item.mainPhotoID = attachment.id; item.updatedAt = Date()
                    do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
                }.accessibilityIdentifier("useMainPhoto")
            }
        }
    }

    var body: some View {
        preview
        .padding(.bottom)
        .navigationTitle(attachment.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit Details", systemImage: "pencil") {
                    editing = true
                }.accessibilityIdentifier("editAttachment")
                Button("Review / Redact", systemImage: "rectangle.fill") { loadReview() }
                    .disabled(preparing || attachment.content == nil).accessibilityIdentifier("reviewAttachment")
                Button("Delete Attachment", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .accessibilityIdentifier("deleteAttachment")
            }
        }
        .overlay { if preparing { ProgressView("Preparing preview…").padding().background(.regularMaterial) } }
        .sheet(isPresented: $editing) { AttachmentMetadataEditor(attachment: attachment) }
        .sheet(item: $review) { document in
            AttachmentReviewView(document: document, title: attachment.title,
                                 role: AttachmentRole(rawValue: attachment.role) ?? .extra, allowsItemPhoto: attachment.item != nil) { prepared in
                do {
                    AttachmentStore.update(attachment, from: prepared)
                    try context.save()
                } catch { context.rollback(); throw error }
            }
        }
        .confirmationDialog("Delete this attachment?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Attachment", role: .destructive) {
                do { try AttachmentStore.delete(attachment, in: context); dismiss() }
                catch { context.rollback(); self.error = error.localizedDescription }
            }
        } message: { Text("This removes the saved copy from this inventory. Your original source file is unchanged.") }
        .formError($error)
    }

    private func loadReview() {
        guard let data = attachment.content else { return }
        preparing = true
        Task {
            defer { preparing = false }
            do { review = try await MediaProcessor.shared.load(data: data) }
            catch { self.error = error.localizedDescription }
        }
    }
}

private struct AttachmentMetadataEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let attachment: Attachment
    @State private var title: String
    @State private var role: AttachmentRole
    @State private var error: String?
    init(attachment: Attachment) {
        self.attachment = attachment
        _title = State(initialValue: attachment.title)
        _role = State(initialValue: AttachmentRole(rawValue: attachment.role) ?? .extra)
    }
    private var roles: [AttachmentRole] {
        AttachmentRole.allCases.filter { $0 != .itemPhoto || (attachment.item != nil && attachment.mediaType == "image") }
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Attachment name", text: $title)
                Picker("Purpose", selection: $role) { ForEach(roles) { Text($0.label).tag($0) } }
            }.formStyle(.grouped).navigationTitle("Attachment Details")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        #if os(macOS)
        .frame(width: 420, height: 220)
        #endif
        .formError($error)
    }
    private func save() {
        attachment.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        attachment.role = role.rawValue
        (attachment.item ?? attachment.coverage?.item)?.updatedAt = Date()
        do { try context.save(); dismiss() } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

private struct SavedMediaView: View {
    let data: Data
    let isPDF: Bool
    @State private var zoom = 1.0
    var body: some View {
        if isPDF {
            PDFPreview(data: data).accessibilityIdentifier("savedPDF")
        } else if let source = CGImageSourceCreateWithData(data as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            VStack {
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        Image(image, scale: 1, label: Text("Saved reviewed image")).resizable().scaledToFit()
                            .frame(width: max(1, geometry.size.width) * zoom)
                            .accessibilityLabel("Saved reviewed image").accessibilityIdentifier("savedImage")
                    }
                }
                HStack { Text("Zoom"); Slider(value: $zoom, in: 1...4).accessibilityLabel("Zoom") }.padding(.horizontal)
            }
        } else {
            ContentUnavailableView("Unable to display attachment", systemImage: "photo.badge.exclamationmark")
        }
    }
}

#if os(macOS)
private struct PDFPreview: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; return view }
    func updateNSView(_ view: PDFView, context: Context) {
        if context.coordinator.data != data { view.document = PDFDocument(data: data); context.coordinator.data = data }
    }
    func makeCoordinator() -> PDFPreviewCache { PDFPreviewCache() }
}
#else
private struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; return view }
    func updateUIView(_ view: PDFView, context: Context) {
        if context.coordinator.data != data { view.document = PDFDocument(data: data); context.coordinator.data = data }
    }
    func makeCoordinator() -> PDFPreviewCache { PDFPreviewCache() }
}
#endif
private final class PDFPreviewCache { var data: Data? }
