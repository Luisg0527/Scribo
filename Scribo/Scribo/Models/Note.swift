import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let subtopic_id: UUID?
    let workspace_id: UUID?
    let user_id: UUID?
    var title: String
    var content: String
    let created_at: String
    let updated_at: String

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content
    }
}
