import Foundation
import SwiftUI
import Supabase

// MARK: - Database Models
struct TopicRecord: Codable {
    let id: UUID
    let user_id: UUID
    let title: String
}

struct SubtopicRecord: Codable {
    let id: UUID
    let topic_id: UUID
    let user_id: UUID
    let title: String
}

struct NoteRecord: Codable {
    let id: UUID
    let user_id: UUID
    let topic_id: UUID
    let subtopic_id: UUID
    let title: String
    let content: String
    let attachment_url: String?
    let created_at: String
    let updated_at: String
}

class DataManager: ObservableObject {
    @Published var topics: [Topic] = []
    private let supabase = SupabaseConfig.shared.client
    
    init() {
        Task {
            await loadTopics()
        }
    }
    
    // MARK: - Topics
    func addTopic(title: String) {
        Task {
            do {
                // Get the current user's ID from the session
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                let newTopic = TopicRecord(
                    id: UUID(), // This will be replaced by the database
                    user_id: userId,
                    title: title
                )
                
                let response = try await supabase
                    .from("topics")
                    .insert(newTopic)
                    .select()
                    .execute()
                
                // Decode the array response and get the first item
                let topicRecords = try JSONDecoder().decode([TopicRecord].self, from: response.data)
                guard let topicRecord = topicRecords.first else {
                    throw NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No topic record returned"])
                }
                
                let topic = Topic(
                    id: topicRecord.id,
                    user_id: topicRecord.user_id,
                    title: topicRecord.title,
                    subtopics: []
                )
                await MainActor.run {
                    topics.append(topic)
                }
            } catch {
                print("Error adding topic: \(error)")
            }
        }
    }
    
    func updateTopic(_ topic: Topic, newTitle: String) {
        Task {
            do {
                let updateData = TopicRecord(
                    id: topic.id,
                    user_id: topic.user_id,
                    title: newTitle
                )
                
                try await supabase
                    .from("topics")
                    .update(updateData)
                    .eq("id", value: topic.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    if let index = topics.firstIndex(where: { $0.id == topic.id }) {
                        topics[index].title = newTitle
                    }
                }
            } catch {
                print("Error updating topic: \(error)")
            }
        }
    }
    
    func deleteTopic(_ topic: Topic) {
        Task {
            do {
                try await supabase
                    .from("topics")
                    .delete()
                    .eq("id", value: topic.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    topics.removeAll { $0.id == topic.id }
                }
            } catch {
                print("Error deleting topic: \(error)")
            }
        }
    }
    
    // MARK: - Subtopics
    func addSubtopic(to topic: Topic, title: String) {
        Task {
            do {
                // Get the current user's ID from the session
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                // Create the subtopic with the exact structure
                let newSubtopic = SubtopicRecord(
                    id: UUID(), // This will be replaced by the database
                    topic_id: topic.id,
                    user_id: userId,
                    title: title
                )
                
                let response = try await supabase
                    .from("subtopics")
                    .insert(newSubtopic)
                    .select()
                    .single()
                    .execute()
                
                let subtopicRecord = try JSONDecoder().decode(SubtopicRecord.self, from: response.data)
                
                let subtopic = Subtopic(
                    id: subtopicRecord.id,
                    topic_id: subtopicRecord.topic_id,
                    title: subtopicRecord.title,
                    notes: []
                )
                
                await MainActor.run {
                    if let index = topics.firstIndex(where: { $0.id == topic.id }) {
                        topics[index].subtopics.append(subtopic)
                    }
                }
            } catch {
                print("Error adding subtopic: \(error)")
            }
        }
    }
    
    func updateSubtopic(_ subtopic: Subtopic, in topic: Topic, newTitle: String) {
        Task {
            do {
                let updateData = SubtopicRecord(
                    id: subtopic.id,
                    topic_id: topic.id,
                    user_id: topic.user_id,
                    title: newTitle
                )
                
                try await supabase
                    .from("subtopics")
                    .update(updateData)
                    .eq("id", value: subtopic.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
                       let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }) {
                        topics[topicIndex].subtopics[subtopicIndex].title = newTitle
                    }
                }
            } catch {
                print("Error updating subtopic: \(error)")
            }
        }
    }
    
    func deleteSubtopic(_ subtopic: Subtopic, from topic: Topic) {
        Task {
            do {
                // Get the current user's ID from the session
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                // First delete all notes associated with this subtopic
                try await supabase
                    .from("notes")
                    .delete()
                    .eq("subtopic_id", value: subtopic.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                // Then delete the subtopic
                try await supabase
                    .from("subtopics")
                    .delete()
                    .eq("id", value: subtopic.id.uuidString)
                    .eq("user_id", value: userId.uuidString)
                    .execute()
                
                // Update local state
                await MainActor.run {
                    if let index = topics.firstIndex(where: { $0.id == topic.id }) {
                        topics[index].subtopics.removeAll { $0.id == subtopic.id }
                    }
                }
            } catch {
                print("Error deleting subtopic: \(error)")
            }
        }
    }
    
    // MARK: - Notes
    func addNote(to subtopic: Subtopic, in topic: Topic, title: String, content: String, attachmentUrl: String? = nil) {
        Task {
            do {
                let session = try await supabase.auth.session
                let userId = session.user.id
                
                let newNote = NoteRecord(
                    id: UUID(),
                    user_id: userId,
                    topic_id: topic.id,
                    subtopic_id: subtopic.id,
                    title: title,
                    content: content,
                    attachment_url: attachmentUrl,
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    updated_at: ISO8601DateFormatter().string(from: Date())
                )
                
                let response = try await supabase
                    .from("notes")
                    .insert(newNote)
                    .select()
                    .execute()
                
                let records = try JSONDecoder().decode([NoteRecord].self, from: response.data)
                guard let record = records.first else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record returned"]) }
                
                let note = Note(
                    id: record.id,
                    title: record.title,
                    content: record.content,
                    attachment_url: record.attachment_url
                )
                
                await MainActor.run {
                    if let index = topics.firstIndex(where: { $0.id == topic.id }),
                       let subtopicIndex = topics[index].subtopics.firstIndex(where: { $0.id == subtopic.id }) {
                        topics[index].subtopics[subtopicIndex].notes.append(note)
                    }
                }
            } catch {
                print("Error adding note: \(error)")
            }
        }
    }
    
    func updateNote(_ note: Note, in subtopic: Subtopic, in topic: Topic, newTitle: String, newContent: String, newAttachmentUrl: String? = nil) {
        Task {
            do {
                var updateData: [String: String] = [
                    "title": newTitle,
                    "content": newContent,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ]
                
                if let attachmentUrl = newAttachmentUrl {
                    updateData["attachment_url"] = attachmentUrl
                }
                
                let response = try await supabase
                    .from("notes")
                    .update(updateData)
                    .eq("id", value: note.id)
                    .select()
                    .execute()
                
                let records = try JSONDecoder().decode([NoteRecord].self, from: response.data)
                guard let record = records.first else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record returned"]) }
                
                let updatedNote = Note(
                    id: record.id,
                    title: record.title,
                    content: record.content,
                    attachment_url: record.attachment_url
                )
                
                // Update the updated_at_check in notes_view
                try await supabase
                    .from("notes_view")
                    .update(["updated_at_check": ISO8601DateFormatter().string(from: Date())])
                    .eq("note_id", value: note.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
                       let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }),
                       let noteIndex = topics[topicIndex].subtopics[subtopicIndex].notes.firstIndex(where: { $0.id == note.id }) {
                        topics[topicIndex].subtopics[subtopicIndex].notes[noteIndex] = updatedNote
                    }
                }
            } catch {
                print("Error updating note: \(error)")
            }
        }
    }
    
    func deleteNote(_ note: Note, from subtopic: Subtopic, from topic: Topic) {
        Task {
            do {
                try await supabase
                    .from("notes")
                    .delete()
                    .eq("id", value: note.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
                       let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }) {
                        topics[topicIndex].subtopics[subtopicIndex].notes.removeAll { $0.id == note.id }
                    }
                }
            } catch {
                print("Error deleting note: \(error)")
            }
        }
    }
    
    // MARK: - Loading Data
    @MainActor
    private func loadTopics() async {
        do {
            let response = try await supabase
                .from("topics")
                .select("""
                    id,
                    user_id,
                    title,
                    subtopics!topic_id (
                        id,
                        topic_id,
                        user_id,
                        title,
                        notes!subtopic_id (
                            id,
                            topic_id,
                            subtopic_id,
                            title,
                            content,
                            attachment_url,
                            created_at,
                            updated_at
                        )
                    )
                """)
                .execute()
            
            let topics = try JSONDecoder().decode([Topic].self, from: response.data)
            self.topics = topics
        } catch {
            print("Error loading topics: \(error)")
        }
    }
    
    // MARK: - User Profile
    func updateUserProfile(fullName: String, avatarImage: UIImage?) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        var updateData: [String: String] = [
            "full_name": fullName
        ]
        
        if let image = avatarImage {
            // Save image to Documents directory
            let fileName = "\(userId).jpg"
            let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
            
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: fileURL)
                updateData["avatar_url"] = fileName
            }
        }
        
        try await supabase
            .from("users")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }
    
    func getUserProfile() async throws -> User {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let response = try await supabase
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
        
        return try JSONDecoder().decode(User.self, from: response.data)
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func getRecentNotes() async throws -> [Note] {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // First get the recent note IDs
        let recentResponse = try await supabase
            .from("notes_view")
            .select("note_id")
            .eq("user_id", value: session.user.id)
            .order("viewed_at", ascending: false)
            .limit(5)
            .execute()
        
        struct RecentNoteRecord: Codable {
            let note_id: String
        }
        
        let recentNotes = try JSONDecoder().decode([RecentNoteRecord].self, from: recentResponse.data)
        
        // Then fetch the actual notes, removing duplicates
        var seenNoteIds = Set<String>()
        var notes: [Note] = []
        
        for recentNote in recentNotes {
            // Skip if we've already seen this note
            if seenNoteIds.contains(recentNote.note_id) {
                continue
            }
            seenNoteIds.insert(recentNote.note_id)
            
            let noteResponse = try await supabase
                .from("notes")
                .select()
                .eq("id", value: recentNote.note_id)
                .single()
                .execute()
            
            if let note = try? JSONDecoder().decode(Note.self, from: noteResponse.data) {
                notes.append(note)
            }
        }
        
        return notes
    }
    
    func addRecentNote(noteId: String) async throws {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let recentNote = [
            "user_id": session.user.id.uuidString,
            "note_id": noteId,
            "viewed_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await supabase
            .from("notes_view")
            .upsert(recentNote, onConflict: "user_id,note_id")
            .execute()
    }
} 
 