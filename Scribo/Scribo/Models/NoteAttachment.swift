import Foundation

/// How image bytes are resolved for a row in `note_attachments` (no extra DB columns).
enum NoteAttachmentImageSemantics {
    /// Object key in Supabase Storage bucket `attachments` (path contains `/`, e.g. `userId/noteId/file.jpg`).
    case supabaseStorage
    /// Full image file in app Documents (`bucket` is `local`).
    case localDeviceFile
    /// Legacy rows: `bucket` is `attachments` but `storage_path` is a single filename (no `/`) on device.
    case legacyLocalInAttachmentsBucket
    /// `storage_path` is a Photos `localIdentifier`; pixels stay in the library (free tier).
    case photoLibraryReference
}

enum NoteAttachmentBuckets {
    static let supabase = "attachments"
    static let localDevice = "local"
    static let photoLibrary = "photo_library"
}

struct NoteAttachment: Identifiable, Codable {
    let id: UUID
    let note_id: UUID
    let uploaded_by: UUID?
    let kind: String
    let bucket: String
    let storage_path: String
    let mime_type: String?
    let size_bytes: Int?
    let created_at: String
    let updated_at: String

    var imageSemantics: NoteAttachmentImageSemantics {
        if bucket == NoteAttachmentBuckets.photoLibrary {
            return .photoLibraryReference
        }
        if bucket == NoteAttachmentBuckets.localDevice {
            return .localDeviceFile
        }
        if bucket == NoteAttachmentBuckets.supabase && !storage_path.contains("/") {
            return .legacyLocalInAttachmentsBucket
        }
        if bucket == NoteAttachmentBuckets.supabase {
            return .supabaseStorage
        }
        if !storage_path.contains("/") {
            return .legacyLocalInAttachmentsBucket
        }
        return .supabaseStorage
    }

    /// Treat as a visual image in grids and note viewer (matches DB `attachment_kind` and mime).
    var isImageLike: Bool {
        if let mime = mime_type?.lowercased(), mime.hasPrefix("image/") { return true }
        let k = kind.lowercased()
        return k == "image" || k == "photo" || k == "camera" || k == "scanned"
    }
}
