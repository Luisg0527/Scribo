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
    let workspace_id: UUID?
    let user_id: UUID?
    let subtopic_id: UUID?
    let title: String
    let content: String
    let created_by: UUID
    let created_at: String
    let updated_at: String
}

// MARK: - Note Attachments
struct NoteAttachmentInsert: Encodable {
    let note_id: UUID
    let uploaded_by: UUID?
    let kind: String
    let bucket: String
    let storage_path: String
    let mime_type: String?
    let size_bytes: Int?
}

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var topics: [Topic] = []
    private let supabase = SupabaseConfig.shared.client
    private let notificationManager = NotificationManager.shared

    private init() {
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
    func addNote(to subtopic: Subtopic, in topic: Topic, title: String, content: String) async throws -> Note {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let newNote = NoteRecord(
            id: UUID(),
            workspace_id: nil,
            user_id: userId,
            subtopic_id: subtopic.id,
            title: title,
            content: content,
            created_by: userId,
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
            workspace_id: record.workspace_id,
            user_id: record.user_id,
            title: record.title,
            content: record.content,
            created_at: record.created_at,
            updated_at: record.updated_at
        )

        await MainActor.run {
            if let index = topics.firstIndex(where: { $0.id == topic.id }),
               let subtopicIndex = topics[index].subtopics.firstIndex(where: { $0.id == subtopic.id }) {
                topics[index].subtopics[subtopicIndex].notes.append(note)
            }
            SoundManager.shared.playCompletionSound()
            notificationManager.scheduleNotification(
                title: "New Note Created",
                body: "Your note '\(title)' has been created successfully"
            )
        }

        // Add to recent notes
        try await addRecentNote(noteId: note.id.uuidString)

        return note
    }

    func updateNote(_ note: Note, in subtopic: Subtopic, in topic: Topic, newTitle: String, newContent: String) async throws -> Note {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let updateData = NoteRecord(
            id: note.id,
            workspace_id: note.workspace_id,
            user_id: note.user_id ?? userId,
            subtopic_id: note.subtopic_id,
            title: newTitle,
            content: newContent,
            created_by: userId,
            created_at: note.created_at,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        let response = try await supabase
            .from("notes")
            .update(updateData)
            .eq("id", value: note.id.uuidString)
            .select()
            .single()
            .execute()

        let updatedNote = try JSONDecoder().decode(Note.self, from: response.data)

        await MainActor.run {
            if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
               let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }),
               let noteIndex = topics[topicIndex].subtopics[subtopicIndex].notes.firstIndex(where: { $0.id == note.id }) {
                topics[topicIndex].subtopics[subtopicIndex].notes[noteIndex] = updatedNote
            }
        }

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
                            workspace_id,
                            user_id,
                            title,
                            content,
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
            .from("profiles")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }

    func getUserProfile() async throws -> User {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let response = try await supabase
            .from("profiles")
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

        let recentResponse = try await supabase
            .from("note_reads")
            .select("note_id")
            .eq("user_id", value: session.user.id)
            .order("last_viewed_at", ascending: false)
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
            "last_viewed_at": ISO8601DateFormatter().string(from: Date())
        ]

        try await supabase
            .from("note_reads")
            .upsert(recentNote, onConflict: "user_id,note_id")
            .execute()
    }

    // MARK: - Note Attachments
    func createAttachment(for noteId: UUID, storagePath: String, mimeType: String?, sizeBytes: Int?, kind: String) async throws -> NoteAttachment {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let insert = NoteAttachmentInsert(
            note_id: noteId,
            uploaded_by: userId,
            kind: kind,
            bucket: "attachments",
            storage_path: storagePath,
            mime_type: mimeType,
            size_bytes: sizeBytes
        )

        let response = try await supabase
            .from("note_attachments")
            .insert(insert)
            .select()
            .single()
            .execute()

        return try JSONDecoder().decode(NoteAttachment.self, from: response.data)
    }

    func getMyAttachments() async throws -> [NoteAttachment] {
        let session = try await supabase.auth.session
        let userId = session.user.id

        let response = try await supabase
            .from("note_attachments")
            .select()
            .eq("uploaded_by", value: userId)
            .order("created_at", ascending: false)
            .execute()

        return try JSONDecoder().decode([NoteAttachment].self, from: response.data)
    }

    func getAttachments(forNoteId noteId: UUID) async throws -> [NoteAttachment] {
        let response = try await supabase
            .from("note_attachments")
            .select()
            .eq("note_id", value: noteId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        return try JSONDecoder().decode([NoteAttachment].self, from: response.data)
    }

    // MARK: - Subscription Management

    func updateUserSubscription(tier: SubscriptionTier) async throws {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let updateData: [String: String] = [
            "subscription_tier": tier.rawValue,
            "subscription_expires_at": ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 24 * 60 * 60)) // 30 days from now
        ]

        try await supabase
            .from("profiles")
            .update(updateData)
            .eq("id", value: session.user.id)
            .execute()

        print("✅ Updated user subscription to \(tier.displayName)")
    }

    func getUserSubscriptionStatus() async throws -> (tier: SubscriptionTier, expiresAt: Date?) {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let response = try await supabase
            .from("profiles")
            .select("subscription_tier, subscription_expires_at")
            .eq("id", value: session.user.id)
            .single()
            .execute()

        // Parse the JSON data properly
        let decoder = JSONDecoder()
        let userData = try decoder.decode([String: String?].self, from: response.data)

        // Handle optional subscription tier
        let tierString = (userData["subscription_tier"] as? String) ?? "free"
        let tier = SubscriptionTier(rawValue: tierString) ?? .free

        // Handle optional expiration date
        var expiresAt: Date?
        if let expiresAtString = userData["subscription_expires_at"] as? String {
            expiresAt = ISO8601DateFormatter().date(from: expiresAtString)
        }

        return (tier: tier, expiresAt: expiresAt)
    }

    func getNoteCount() async throws -> Int {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Get all notes for the user and count them
        let response = try await supabase
            .from("notes")
            .select("id")
            .execute()

        // Parse the response to get the count
        let decoder = JSONDecoder()
        let notes = try decoder.decode([[String: String]].self, from: response.data)
        return notes.count
    }

    func getTopicCount() async throws -> Int {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Get all topics for the user and count them
        let response = try await supabase
            .from("topics")
            .select("id")
            .eq("user_id", value: session.user.id)
            .execute()

        // Parse the response to get the count
        let decoder = JSONDecoder()
        let topics = try decoder.decode([[String: String]].self, from: response.data)
        return topics.count
    }

    func getSubtopicCount() async throws -> Int {
        guard let session = try? await supabase.auth.session else {
            throw NSError(domain: "DataManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // Get all subtopics for the user and count them
        let response = try await supabase
            .from("subtopics")
            .select("id")
            .eq("user_id", value: session.user.id)
            .execute()

        // Parse the response to get the count
        let decoder = JSONDecoder()
        let subtopics = try decoder.decode([[String: String]].self, from: response.data)
        return subtopics.count
    }

    func canCreateNote() async throws -> Bool {
        let noteCount = try await getNoteCount()
        let subscriptionStatus = try await getUserSubscriptionStatus()
        let limit = subscriptionStatus.tier.limits.maxNotes

        return limit == -1 || noteCount < limit
    }

    func canCreateTopic() async throws -> Bool {
        let topicCount = try await getTopicCount()
        let subscriptionStatus = try await getUserSubscriptionStatus()
        let limit = subscriptionStatus.tier.limits.maxTopics

        return limit == -1 || topicCount < limit
    }

    func canCreateSubtopic() async throws -> Bool {
        let subtopicCount = try await getSubtopicCount()
        let subscriptionStatus = try await getUserSubscriptionStatus()
        let limit = subscriptionStatus.tier.limits.maxSubtopics

        return limit == -1 || subtopicCount < limit
    }
}
