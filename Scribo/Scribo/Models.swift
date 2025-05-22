import Foundation

// MARK: - Models
struct Topic: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var subtopics: [Subtopic]
}

struct Subtopic: Identifiable, Codable {
    let id: UUID
    let topic_id: UUID
    var title: String
    var notes: [Note]
}

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var attachment_url: String?
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.attachment_url == rhs.attachment_url
    }
}

class User: Codable {
    let id: UUID
    var full_name: String
    var avatar_url: String?
    let created_at: String
}

// MARK: - Search State
class SearchState: ObservableObject {
    @Published var searchText: String = ""
} 