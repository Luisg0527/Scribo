import Foundation
import SwiftUI
import Supabase

// MARK: - Database Models
struct TopicRecord: Codable {
    let id: UUID
    let user_id: String
    let title: String
    
    init(user_id: String, title: String) {
        self.id = UUID()
        self.user_id = user_id
        self.title = title
    }
}

struct SubtopicRecord: Codable {
    let id: UUID
    let topic_id: UUID
    let title: String
    
    init(topic_id: UUID, title: String) {
        self.id = UUID()
        self.topic_id = topic_id
        self.title = title
    }
}

struct NoteRecord: Codable {
    let id: UUID
    let topic_id: UUID
    let subtopic_id: UUID
    let title: String
    let content: String
    let photo_url: String?
    let date: Date
    
    init(topic_id: UUID, subtopic_id: UUID, title: String, content: String, photo_url: String?, date: Date) {
        self.id = UUID()
        self.topic_id = topic_id
        self.subtopic_id = subtopic_id
        self.title = title
        self.content = content
        self.photo_url = photo_url
        self.date = date
    }
}

class DataManager: ObservableObject {
    @Published var topics: [Topic] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let supabase: SupabaseClient
    private let authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
        let supabaseKey = "YOUR_SUPABASE_KEY"
        self.supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        
        // Load initial data
        Task {
            await loadTopics()
        }
    }
    
    // MARK: - Topics
    
    func loadTopics() async {
        guard let userId = authManager.currentUser?.id else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            let topics: [Topic] = try await supabase
                .database
                .from("topics")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.topics = topics
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func createTopic(_ topic: Topic) async throws {
        guard let userId = authManager.currentUser?.id else { return }
        
        var newTopic = topic
        newTopic.userId = userId
        
        let createdTopic: Topic = try await supabase
            .database
            .from("topics")
            .insert(newTopic)
            .execute()
            .value
        
        DispatchQueue.main.async {
            self.topics.append(createdTopic)
        }
    }
    
    func updateTopic(_ topic: Topic) async throws {
        let updatedTopic: Topic = try await supabase
            .database
            .from("topics")
            .update(topic)
            .eq("id", value: topic.id)
            .execute()
            .value
        
        DispatchQueue.main.async {
            if let index = self.topics.firstIndex(where: { $0.id == topic.id }) {
                self.topics[index] = updatedTopic
            }
        }
    }
    
    func deleteTopic(_ topic: Topic) async throws {
        try await supabase
            .database
            .from("topics")
            .delete()
            .eq("id", value: topic.id)
            .execute()
        
        DispatchQueue.main.async {
            self.topics.removeAll { $0.id == topic.id }
        }
    }
    
    // MARK: - Notes
    
    func loadNotes(for topic: Topic) async throws -> [Note] {
        let notes: [Note] = try await supabase
            .database
            .from("notes")
            .select()
            .eq("topic_id", value: topic.id)
            .execute()
            .value
        
        return notes
    }
    
    func createNote(_ note: Note) async throws {
        let createdNote: Note = try await supabase
            .database
            .from("notes")
            .insert(note)
            .execute()
            .value
        
        DispatchQueue.main.async {
            if let index = self.topics.firstIndex(where: { $0.id == note.topicId }) {
                self.topics[index].notes.append(createdNote)
            }
        }
    }
    
    func updateNote(_ note: Note) async throws {
        let updatedNote: Note = try await supabase
            .database
            .from("notes")
            .update(note)
            .eq("id", value: note.id)
            .execute()
            .value
        
        DispatchQueue.main.async {
            if let topicIndex = self.topics.firstIndex(where: { $0.id == note.topicId }),
               let noteIndex = self.topics[topicIndex].notes.firstIndex(where: { $0.id == note.id }) {
                self.topics[topicIndex].notes[noteIndex] = updatedNote
            }
        }
    }
    
    func deleteNote(_ note: Note) async throws {
        try await supabase
            .database
            .from("notes")
            .delete()
            .eq("id", value: note.id)
            .execute()
        
        DispatchQueue.main.async {
            if let topicIndex = self.topics.firstIndex(where: { $0.id == note.topicId }) {
                self.topics[topicIndex].notes.removeAll { $0.id == note.id }
            }
        }
    }
} 
 