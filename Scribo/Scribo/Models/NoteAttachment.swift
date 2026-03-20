import Foundation

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
}
