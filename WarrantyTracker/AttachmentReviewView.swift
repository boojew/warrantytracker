import SwiftUI

struct AttachmentReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State var document: ReviewDocument
    @State var title: String
    @State var role: AttachmentRole
    let allowsItemPhoto: Bool
    let onSave: (PreparedAttachment) throws -> Void
    @State private var pageIndex = 0
    @State private var zoom = 1.0
    @State private var covering = false
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    TextField("Attachment name", text: $title).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("attachmentTitle")
                    Picker("Purpose", selection: $role) {
                        ForEach(AttachmentRole.allCases.filter { ($0 != .itemPhoto || (allowsItemPhoto && !document.isPDF)) && (allowsItemPhoto || $0 == .policy || $0 == .extra || $0 == .receipt) }) {
                            Text($0.label).tag($0)
                        }
                    }.accessibilityIdentifier("attachmentRole")
                    Text("Cover full card numbers and security codes. Only this reviewed copy will be saved; source files stay unchanged.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if document.isPDF {
                        Text("PDF pages are saved as images, so covered text cannot remain hidden underneath. Review every page for legibility.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    HStack {
                        Toggle("Cover areas", isOn: $covering).toggleStyle(.button)
                            .accessibilityIdentifier("coverAreas")
                        Button("Undo cover") { _ = document.pages[pageIndex].redactions.popLast() }
                            .disabled(document.pages[pageIndex].redactions.isEmpty).accessibilityIdentifier("undoCover")
                        Spacer()
                    }
                    HStack {
                        Button("Previous page", systemImage: "chevron.left") { pageIndex -= 1; zoom = 1 }
                            .labelStyle(.iconOnly).disabled(pageIndex == 0)
                        Text("Page \(pageIndex + 1) of \(document.pages.count)").font(.caption).monospacedDigit()
                            .accessibilityIdentifier("pageIndicator")
                        Button("Next page", systemImage: "chevron.right") { pageIndex += 1; zoom = 1 }
                            .labelStyle(.iconOnly).disabled(pageIndex == document.pages.count - 1)
                        Spacer()
                        Text("Zoom").font(.caption)
                        Slider(value: $zoom, in: 1...3).frame(maxWidth: 130).accessibilityLabel("Zoom")
                    }
                }.padding(.horizontal)
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        let image = document.pages[pageIndex].image
                        let width = max(1, geometry.size.width - 24) * zoom
                        RedactionCanvas(page: $document.pages[pageIndex], covering: covering)
                            .id(document.pages[pageIndex].id)
                            .frame(width: width, height: width * CGFloat(image.height) / CGFloat(image.width))
                            .padding(12)
                    }
                    .background(.gray.opacity(0.12))
                }
                Text(covering ? "Drag across the image to cover an area. Turn off Cover areas to scroll." : "Zoom in to check small text. Turn on Cover areas to draw black rectangles.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Review Attachment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Use Reviewed Copy") { save() }
                        .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveAttachment")
                }
            }
            .disabled(saving)
            .overlay { if saving { ProgressView("Preparing reviewed copy…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 760, minHeight: 680, idealHeight: 800)
        #endif
        .interactiveDismissDisabled()
        .formError($error)
    }

    private func save() {
        saving = true
        Task {
            do {
                let prepared = try await MediaProcessor.shared.prepare(document, title: title, role: role)
                try onSave(prepared)
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}

private struct RedactionCanvas: View {
    @Binding var page: ReviewPage
    let covering: Bool
    @State private var dragRect: CGRect?

    var body: some View {
        GeometryReader { geometry in
            Image(page.image, scale: 1, label: Text("Attachment review image")).resizable()
                .overlay {
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(page.redactions.enumerated()), id: \.offset) { _, rect in mask(rect, size: geometry.size) }
                        if let dragRect { mask(dragRect, size: geometry.size) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                    dragRect = normalized(value, size: geometry.size)
                }.onEnded { value in
                    let rect = normalized(value, size: geometry.size)
                    if rect.width > 0.002 && rect.height > 0.002 { page.redactions.append(rect) }
                    dragRect = nil
                }, including: covering ? .all : .none)
                .accessibilityLabel("Attachment review image")
                .accessibilityIdentifier("redactionCanvas")
                .accessibilityHint("Enable Cover areas, then drag over sensitive information.")
        }
    }

    private func normalized(_ value: DragGesture.Value, size: CGSize) -> CGRect {
        let x1 = min(1, max(0, value.startLocation.x / size.width)), y1 = min(1, max(0, value.startLocation.y / size.height))
        let x2 = min(1, max(0, value.location.x / size.width)), y2 = min(1, max(0, value.location.y / size.height))
        return CGRect(x: min(x1, x2), y: min(y1, y2), width: abs(x2 - x1), height: abs(y2 - y1))
    }

    private func mask(_ rect: CGRect, size: CGSize) -> some View {
        Rectangle().fill(.black).frame(width: rect.width * size.width, height: rect.height * size.height)
            .offset(x: rect.minX * size.width, y: rect.minY * size.height)
    }
}
