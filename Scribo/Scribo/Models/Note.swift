import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var photoURL: URL?
    var createdAt: Date
    var updatedAt: Date
    var topicId: UUID?
    var subtopicId: UUID?
    
    init(id: UUID = UUID(), title: String, content: String, photoURL: URL? = nil, topicId: UUID? = nil, subtopicId: UUID? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.photoURL = photoURL
        self.createdAt = Date()
        self.updatedAt = Date()
        self.topicId = topicId
        self.subtopicId = subtopicId
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.photoURL == rhs.photoURL &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.topicId == rhs.topicId &&
        lhs.subtopicId == rhs.subtopicId
    }
}

struct Topic: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var subtopics: [Subtopic] = []
    var notes: [Note] = []
    
    init(id: UUID = UUID(), title: String, description: String) {
        self.id = id
        self.title = title
        self.description = description
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct Subtopic: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var topicId: UUID
    var createdAt: Date
    var updatedAt: Date
    var notes: [Note] = []
    
    init(id: UUID = UUID(), title: String, description: String, topicId: UUID) {
        self.id = id
        self.title = title
        self.description = description
        self.topicId = topicId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
} 