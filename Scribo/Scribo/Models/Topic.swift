import Foundation

struct Topic: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var subtopics: [Subtopic]
    let created_at: String
    let updated_at: String
}

struct Subtopic: Identifiable, Codable {
    let id: UUID
    let topic_id: UUID
    var title: String
    var notes: [Note]
    let created_at: String
    let updated_at: String
}
