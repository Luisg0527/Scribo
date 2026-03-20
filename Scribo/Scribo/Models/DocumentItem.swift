import Foundation
import UIKit

// MARK: - Classification Response
struct TextClassificationResponse: Codable {
    let topic: String
    let subtopic: String
    let note_name: String
    let raw_scores: [String: Double]
}

// MARK: - Document Type
enum DocumentType: String {
    case photo = "photo"
    case scanned = "scanned"
    case document = "document"
    case camera = "camera"
}

// MARK: - Document Item
struct DocumentItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let type: DocumentType
    let date: Date
    let image: UIImage?
    let documentURL: URL?
    var category: String?
    var topic: String?
    var subtopic: String?
    var noteId: UUID?
    var previewText: String?

    static func == (lhs: DocumentItem, rhs: DocumentItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Card sheet context (for Everything tab sheet)
struct CardSheetContext: Identifiable {
    let note: Note
    let topic: Topic
    let subtopic: Subtopic
    var id: UUID { note.id }
}
