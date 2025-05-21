import Foundation

class SearchState: ObservableObject {
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var searchResults: [SearchResult] = []
    
    func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // TODO: Implement actual search logic
        // This is a placeholder for demonstration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.searchResults = []
            self.isSearching = false
        }
    }
}

struct SearchResult: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let type: SearchResultType
    let topicId: UUID?
    let subtopicId: UUID?
    let noteId: UUID?
}

enum SearchResultType {
    case topic
    case subtopic
    case note
} 