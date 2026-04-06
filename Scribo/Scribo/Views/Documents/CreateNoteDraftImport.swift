import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PDFKit

// MARK: - Create note: file → draft photos + text (shared)
enum CreateNoteDraftDocument {
    static func load(url: URL) -> (photos: [PendingNotePhoto], noteContent: String) {
        let ext = url.pathExtension.lowercased()

        if ["jpg", "jpeg", "png", "heic", "gif", "webp", "bmp", "tiff", "tif"].contains(ext) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return ([PendingNotePhoto(image: image, photoLibraryAssetId: nil)], "")
            }
        }

        if ext == "pdf" {
            if let image = renderFirstPageThumbnailOfPDF(at: url) {
                return ([PendingNotePhoto(image: image, photoLibraryAssetId: nil)], "")
            }
        }

        if ["txt", "text", "md", "markdown", "csv", "json", "xml"].contains(ext) {
            if let data = try? Data(contentsOf: url) {
                let str = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .utf16)
                    ?? ""
                if !str.isEmpty {
                    return ([], str)
                }
            }
        }

        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return ([PendingNotePhoto(image: image, photoLibraryAssetId: nil)], "")
        }

        return ([], "")
    }

    private static func renderFirstPageThumbnailOfPDF(at url: URL) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 800, height: 800), for: .mediaBox)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedDocument: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .text, .plainText, .image, .jpeg, .png, .gif, .webP, .heic, .heif]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedDocument = url
        }
    }
}

// MARK: - Pending attachment while composing a new note
struct PendingNotePhoto: Identifiable {
    let id: UUID
    var image: UIImage
    let photoLibraryAssetId: String?

    init(id: UUID = UUID(), image: UIImage, photoLibraryAssetId: String?) {
        self.id = id
        self.image = image
        self.photoLibraryAssetId = photoLibraryAssetId
    }
}
