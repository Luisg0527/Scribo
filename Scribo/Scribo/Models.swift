import Foundation

// MARK: - Models
struct Topic: Identifiable {
    let id = UUID()
    var title: String
    var subtopics: [Subtopic]
    var date: Date
}

struct Subtopic: Identifiable {
    let id = UUID()
    var title: String
    var notes: [Note]
    var date: Date
}

struct Note: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var content: String
    var photoURL: URL?
    var date: Date
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.photoURL == rhs.photoURL &&
        lhs.date == rhs.date
    }
}

// MARK: - Search State
class SearchState: ObservableObject {
    @Published var searchText: String = ""
} 