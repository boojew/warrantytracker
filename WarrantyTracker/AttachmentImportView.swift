import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import AVFoundation
import UIKit
#endif

struct AttachmentImportView: View {
    @Environment(\.dismiss) private var dismiss
    let defaultRole: AttachmentRole
    let allowsItemPhoto: Bool
    let onSave: (PreparedAttachment) throws -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var choosingFile = false
    @State private var document: ReviewDocument?
    @State private var busy = false
    @State private var error: String?
    @State private var accepted = false
    #if os(iOS)
    @State private var showingCamera = false
    @State private var cameraData: Data?
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images, preferredItemEncoding: .compatible) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }.accessibilityIdentifier("choosePhoto")
                    Button("Choose Image or PDF", systemImage: "doc") { choosingFile = true }
                        .accessibilityIdentifier("chooseAttachmentFile")
                    #if os(iOS)
                    Button("Take Photo", systemImage: "camera") { Task { await openCamera() } }
                        .accessibilityIdentifier("takeAttachmentPhoto")
                    #endif
                } footer: { Text("Review and cover sensitive details before saving. Images are limited to 30 MB; PDFs to 20 pages and 30 MB, with an additional limit for large pages.") }
                if busy { ProgressView("Preparing preview…") }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Attachment")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .disabled(busy)
        }
        #if os(macOS)
        .frame(width: 460, height: 280)
        #endif
        .interactiveDismissDisabled(busy)
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.image, .pdf]) { result in
            switch result {
            case .success(let url): load(url: url)
            case .failure(let error): self.error = error.localizedDescription
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            busy = true
            Task {
                defer { busy = false; selectedPhoto = nil }
                do {
                    guard let file = try await photo.loadTransferable(type: PickedPhoto.self) else {
                        throw FormError.message("The photo could not be loaded. Try importing it from Files.")
                    }
                    document = try await MediaProcessor.shared.load(data: file.data)
                } catch { self.error = error.localizedDescription }
            }
        }
        .sheet(item: $document, onDismiss: { if accepted { dismiss() } }) { document in
            AttachmentReviewView(document: document, title: defaultRole.label,
                                 role: document.isPDF && defaultRole == .itemPhoto ? .extra : defaultRole,
                                 allowsItemPhoto: allowsItemPhoto) { prepared in
                try onSave(prepared)
                accepted = true
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingCamera, onDismiss: {
            if let cameraData { load(data: cameraData); self.cameraData = nil }
        }) {
            CameraCapture { result in
                switch result {
                case .success(let data): cameraData = data
                case .failure(let error): self.error = error.localizedDescription
                }
                showingCamera = false
            } onCancel: { showingCamera = false }
        }
        #endif
        .formError($error, title: "Unable to import")
    }

    private func load(url: URL) {
        busy = true
        Task {
            defer { busy = false }
            do { document = try await MediaProcessor.shared.load(url: url) }
            catch { self.error = error.localizedDescription }
        }
    }
    private func load(data: Data) {
        busy = true
        Task {
            defer { busy = false }
            do { document = try await MediaProcessor.shared.load(data: data) }
            catch { self.error = error.localizedDescription }
        }
    }

    #if os(iOS)
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            error = "A camera is not available on this device. Choose Photos or Files instead."
            return
        }
        var allowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            allowed = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard allowed else {
            error = "Camera access is off. Enable it for WarrantyTracker in iPhone Settings, or choose Photos or Files."
            return
        }
        showingCamera = true
    }
    #endif
}

#if os(iOS)
private struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: (Result<Data, Error>) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.image.identifier]
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(parent: CameraCapture) { self.parent = parent }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCapture(.failure(FormError.message("The camera did not return a photo."))); return
            }
            // Draw once to normalize camera orientation. The capture is never written to Photos or disk by the app.
            let scale = min(1, 4096 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                UIColor.white.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let data = normalized.jpegData(compressionQuality: 1) else {
                parent.onCapture(.failure(FormError.message("Unable to read the captured photo."))); return
            }
            parent.onCapture(.success(data))
        }
    }
}
#endif
