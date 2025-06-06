import Foundation
import SwiftUI
import Supabase

// MARK: - Database Models
struct TopicRecord: Codable {
    let id: UUID
    let user_id: UUID
    let title: String
    let created_at: String
    let updated_at: String
}

struct SubtopicRecord: Codable {
    let id: UUID
    let topic_id: UUID
    let title: String
    let created_at: String
    let updated_at: String
}

struct NoteRecord: Codable {
    let id: UUID
    let subtopic_id: UUID
    let title: String
    let content: String
    let attachment_urls: [String]?
    let created_at: String
    let updated_at: String
}

// MARK: - Upload Request
struct UploadRequest: Codable {
    let title: String
    let type: String
    let image_url: String?
    let document_url: String?
    let category: String?
    let topic: String?
    let subtopic: String?
    let note_id: UUID
}

class DataManager: ObservableObject {
    @Published var topics: [Topic] = []
    private let supabase = SupabaseConfig.shared.client
    private let notificationManager = NotificationManager.shared
    
    init() {
        Task {
            await loadTopics()
        }
    }
    
    // MARK: - Topics
    func addTopic(title: String) async throws -> Topic {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let newTopic = TopicRecord(
            id: UUID(),
            user_id: userId,
            title: title,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await supabase
            .from("topics")
            .insert(newTopic)
            .select()
            .execute()
        
        let topicRecords = try JSONDecoder().decode([TopicRecord].self, from: response.data)
        guard let topicRecord = topicRecords.first else {
            throw NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No topic record returned"])
        }
        
        let topic = Topic(
            id: topicRecord.id,
            user_id: topicRecord.user_id,
            title: topicRecord.title,
            subtopics: [],
            created_at: topicRecord.created_at,
            updated_at: topicRecord.updated_at
        )
        
        await MainActor.run {
            topics.append(topic)
        }
        
        return topic
    }
    
    func updateTopic(_ topic: Topic, newTitle: String) async throws {
        let updateData = TopicRecord(
            id: topic.id,
            user_id: topic.user_id,
            title: newTitle,
            created_at: topic.created_at,
            updated_at: ISO8601DateFormatter().string(from: Date())
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
    func addSubtopic(to topic: Topic, title: String) async throws -> Subtopic {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let newSubtopic = SubtopicRecord(
            id: UUID(),
            topic_id: topic.id,
            title: title,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
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
            notes: [],
            created_at: subtopicRecord.created_at,
            updated_at: subtopicRecord.updated_at
        )
        
        await MainActor.run {
            if let index = topics.firstIndex(where: { $0.id == topic.id }) {
                topics[index].subtopics.append(subtopic)
            }
        }
        
        return subtopic
    }
    
    func updateSubtopic(_ subtopic: Subtopic, in topic: Topic, newTitle: String) async throws {
        let updateData = SubtopicRecord(
            id: subtopic.id,
            topic_id: topic.id,
            title: newTitle,
            created_at: subtopic.created_at,
            updated_at: ISO8601DateFormatter().string(from: Date())
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
    }
    
    func deleteSubtopic(_ subtopic: Subtopic, from topic: Topic) {
        Task {
            do {
                // First delete all notes in the subtopic
                for note in subtopic.notes {
                    try await supabase
                        .from("notes")
                        .delete()
                        .eq("id", value: note.id)
                        .execute()
                }
                
                // Then delete the subtopic
                try await supabase
                    .from("subtopics")
                    .delete()
                    .eq("id", value: subtopic.id)
                    .execute()
                
                // Update local state
                await MainActor.run {
                    if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }) {
                        topics[topicIndex].subtopics.removeAll { $0.id == subtopic.id }
                    }
                }
            } catch {
                print("Error deleting subtopic: \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Notes
    func addNote(to subtopic: Subtopic, in topic: Topic, title: String, content: String, attachmentUrls: [String]? = nil) async throws -> Note {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let newNote = NoteRecord(
            id: UUID(),
            subtopic_id: subtopic.id,
            title: title,
            content: content,
            attachment_urls: attachmentUrls,
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
            subtopic_id: record.subtopic_id,
            title: record.title,
            content: record.content,
            attachment_urls: record.attachment_urls,
            created_at: record.created_at,
            updated_at: record.updated_at
        )
        
        await MainActor.run {
            if let index = topics.firstIndex(where: { $0.id == topic.id }),
               let subtopicIndex = topics[index].subtopics.firstIndex(where: { $0.id == subtopic.id }) {
                topics[index].subtopics[subtopicIndex].notes.append(note)
            }
            notificationManager.playSound(.success)
            notificationManager.scheduleNotification(
                title: "New Note Created",
                body: "Your note '\(title)' has been created successfully"
            )
        }
        
        // Add to recent notes
        try await addRecentNote(noteId: note.id.uuidString)
        
        return note
    }
    
    func updateNote(_ note: Note, in subtopic: Subtopic, in topic: Topic, newTitle: String, newContent: String, newAttachmentUrls: [String]? = nil) async throws -> Note {
        let updateData = NoteRecord(
            id: note.id,
            subtopic_id: note.subtopic_id,
            title: newTitle,
            content: newContent,
            attachment_urls: newAttachmentUrls,
            created_at: note.created_at,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response = try await supabase
            .from("notes")
            .update(updateData)
            .eq("id", value: note.id.uuidString)
            .select()
            .execute()
        
        let records = try JSONDecoder().decode([NoteRecord].self, from: response.data)
        guard let record = records.first else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No record returned"]) }
        
        let updatedNote = Note(
            id: record.id,
            subtopic_id: record.subtopic_id,
            title: record.title,
            content: record.content,
            attachment_urls: record.attachment_urls,
            created_at: record.created_at,
            updated_at: record.updated_at
        )
        
        // Update the updated_at_check in notes_view
        try await supabase
            .from("notes_view")
            .update(["updated_at_check": ISO8601DateFormatter().string(from: Date())])
            .eq("note_id", value: note.id)
            .execute()
        
        await MainActor.run {
            if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
               let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }),
               let noteIndex = topics[topicIndex].subtopics[subtopicIndex].notes.firstIndex(where: { $0.id == note.id }) {
                topics[topicIndex].subtopics[subtopicIndex].notes[noteIndex] = updatedNote
            }
        }
        
        // Add to recent notes
        try await addRecentNote(noteId: note.id.uuidString)
        
        return updatedNote
    }
    
    func deleteNote(_ note: Note, from subtopic: Subtopic, from topic: Topic) {
        Task {
            do {
                // Delete the note (notes_view records will be automatically deleted due to ON DELETE CASCADE)
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
                    notificationManager.playSound(.delete)
                    notificationManager.scheduleNotification(
                        title: "Note Deleted",
                        body: "Your note '\(note.title)' has been deleted"
                    )
                }
            } catch {
                print("Error deleting note: \(error)")
                notificationManager.playSound(.error)
            }
        }
    }
    
    // MARK: - Loading Data
    @MainActor
    func loadTopics() async {
        do {
            let response = try await supabase
                .from("topics")
                .select("""
                    id,
                    user_id,
                    title,
                    created_at,
                    updated_at,
                    subtopics!topic_id (
                        id,
                        topic_id,
                        title,
                        created_at,
                        updated_at,
                        notes!subtopic_id (
                            id,
                            subtopic_id,
                            title,
                            content,
                            attachment_urls,
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
    func getUserEmail() async throws -> String {
        let session = try await supabase.auth.session
        return session.user.email ?? ""
    }
    
    func updateUserEmail(_ newEmail: String) async throws {
        try await supabase.auth.update(user: UserAttributes(email: newEmail))
    }

    func updateUserProfile(fullName: String, avatarImage: UIImage?) async throws {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        var updateData: [String: String] = [
            "full_name": fullName
        ]
        
        if let image = avatarImage {
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
            .eq("auth_id", value: userId)
            .execute()
    }
    
    func getUserProfile() async throws -> User {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let response = try await supabase
            .from("users")
            .select()
            .eq("auth_id", value: userId)
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
        
        var seenNoteIds = Set<String>()
        var notes: [Note] = []
        
        for recentNote in recentNotes {
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
    
    // MARK: - Uploads
    func getUploads() async throws -> [Upload] {
        let response = try await supabase
            .from("uploads")
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        return try JSONDecoder().decode([Upload].self, from: response.data)
    }
    
    func createUpload(_ upload: UploadRequest) async throws -> Upload {
        let response = try await supabase
            .from("uploads")
            .insert(upload)
            .select()
            .single()
            .execute()
        
        return try JSONDecoder().decode(Upload.self, from: response.data)
    }
} 
 