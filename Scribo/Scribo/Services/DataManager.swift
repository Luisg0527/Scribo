import Foundation
import SwiftUI
import Supabase
import UIKit
import Photos
import CryptoKit

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

// MARK: - Note sharing (link + public RPC)

enum NoteShareInviteURL {
    static let httpsBase = "https://scribo.app"

    /// Legacy single-note share (`get_note_by_share_token`).
    static func httpsInviteURL(for token: UUID) -> String {
        "\(httpsBase)/n/\(token.uuidString)"
    }

    /// Whole notebook (topic + subtopics + notes) — `get_notebook_by_share_token`.
    static func httpsNotebookInviteURL(for token: UUID) -> String {
        "\(httpsBase)/b/\(token.uuidString)"
    }

    /// Legacy: note-only custom scheme.
    static func customSchemeInviteURL(for token: UUID) -> String {
        var c = URLComponents()
        c.scheme = "scribo"
        c.host = "share"
        c.queryItems = [URLQueryItem(name: "token", value: token.uuidString)]
        return c.url?.absoluteString ?? "scribo://share?token=\(token.uuidString)"
    }

    /// Whole notebook on custom scheme (`scribo://notebook?token=`).
    static func customSchemeNotebookInviteURL(for token: UUID) -> String {
        var c = URLComponents()
        c.scheme = "scribo"
        c.host = "notebook"
        c.queryItems = [URLQueryItem(name: "token", value: token.uuidString)]
        return c.url?.absoluteString ?? "scribo://notebook?token=\(token.uuidString)"
    }
}

private struct NoteShareLinkTokenRow: Codable {
    let token: UUID
    let revoked_at: String?
}

struct SharedNotePayload: Codable {
    let note_id: UUID
    let title: String
    let content: String
    let updated_at: String
    let share_role: String?
    let workspace_id: UUID?
}

private struct NoteShareLinkInsert: Encodable {
    let note_id: UUID
    let created_by: UUID
}

private struct TopicShareLinkTokenRow: Codable {
    let token: UUID
    let revoked_at: String?
}

private struct TopicShareLinkInsert: Encodable {
    let topic_id: UUID
    let created_by: UUID
}

private struct ShareTokenRPCParams: Encodable {
    let p_token: UUID
}

/// Response from `get_notebook_by_share_token` — build a local `Topic` for read-only UI.
struct SharedNotebookPayload: Codable {
    let topic: SharedNotebookTopicRow
    let subtopics: [SharedNotebookSubtopicRow]

    struct SharedNotebookTopicRow: Codable {
        let id: UUID
        let user_id: UUID
        let title: String
        let created_at: String
        let updated_at: String
    }

    struct SharedNotebookSubtopicRow: Codable {
        let id: UUID
        let topic_id: UUID
        let title: String
        let created_at: String
        let updated_at: String
        let notes: [Note]
    }

    func asTopic() -> Topic {
        let subs = subtopics.map { row in
            Subtopic(
                id: row.id,
                topic_id: row.topic_id,
                title: row.title,
                notes: row.notes,
                created_at: row.created_at,
                updated_at: row.updated_at
            )
        }
        return Topic(
            id: topic.id,
            user_id: topic.user_id,
            title: topic.title,
            subtopics: subs,
            created_at: topic.created_at,
            updated_at: topic.updated_at
        )
    }

    func makeLibraryEntry(shareToken: UUID, addedAt: Date = Date()) -> SavedSharedNotebookEntry {
        let t = asTopic()
        let notes = t.subtopics.flatMap(\.notes)
        let snippet = notes.first(where: { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .map { String($0.content.prefix(160)) }
        return SavedSharedNotebookEntry(
            shareToken: shareToken,
            title: t.title,
            subtopicCount: t.subtopics.count,
            noteCount: notes.count,
            previewSnippet: snippet,
            addedAt: addedAt
        )
    }
}

/// A notebook someone opened via share link (`/b/…`), kept in the Notebook tab for quick access (still view-only).
struct SavedSharedNotebookEntry: Codable, Identifiable, Equatable {
    let shareToken: UUID
    var title: String
    var subtopicCount: Int
    var noteCount: Int
    var previewSnippet: String?
    var addedAt: Date

    var id: UUID { shareToken }
}

class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var topics: [Topic] = []
    @Published var savedSharedNotebookEntries: [SavedSharedNotebookEntry] = []
    private let supabase = SupabaseConfig.shared.client
    private let notificationManager = NotificationManager.shared

    private init() {
        Task { await loadTopics() }
    }

    /// Call on sign-out so the next user never sees the previous account’s notebook.
    @MainActor
    func clearNotebookData() {
        topics = []
        savedSharedNotebookEntries = []
    }

    private func savedSharedNotebooksKey(_ userId: UUID) -> String {
        "scribo.savedSharedNotebooks.\(userId.uuidString)"
    }

    @MainActor
    private func loadSavedSharedNotebooks(userId: UUID) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let data = UserDefaults.standard.data(forKey: savedSharedNotebooksKey(userId)),
              let list = try? dec.decode([SavedSharedNotebookEntry].self, from: data) else {
            savedSharedNotebookEntries = []
            return
        }
        savedSharedNotebookEntries = list.sorted { $0.addedAt > $1.addedAt }
    }

    @MainActor
    private func persistSavedSharedNotebooks(userId: UUID) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(savedSharedNotebookEntries) else { return }
        UserDefaults.standard.set(data, forKey: savedSharedNotebooksKey(userId))
    }

    /// Upsert metadata when a shared notebook is opened (scan, link, or library).
    func addOrUpdateSharedNotebookInLibrary(shareToken: UUID, payload: SharedNotebookPayload) async {
        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch { return }
        let existingAdded = await MainActor.run {
            savedSharedNotebookEntries.first(where: { $0.shareToken == shareToken })?.addedAt
        }
        let addedAt = existingAdded ?? Date()
        let newEntry = payload.makeLibraryEntry(shareToken: shareToken, addedAt: addedAt)
        await MainActor.run {
            if let idx = savedSharedNotebookEntries.firstIndex(where: { $0.shareToken == shareToken }) {
                savedSharedNotebookEntries[idx] = newEntry
            } else {
                savedSharedNotebookEntries.insert(newEntry, at: 0)
            }
            persistSavedSharedNotebooks(userId: userId)
        }
    }

    func removeSavedSharedNotebook(shareToken: UUID) async {
        let userId: UUID
        do {
            userId = try await supabase.auth.session.user.id
        } catch { return }
        await MainActor.run {
            savedSharedNotebookEntries.removeAll { $0.shareToken == shareToken }
            persistSavedSharedNotebooks(userId: userId)
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
            let session = try await supabase.auth.session
            let userId = session.user.id
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
                .eq("user_id", value: userId)
                .execute()

            let topics = try JSONDecoder().decode([Topic].self, from: response.data)
            self.topics = topics
            loadSavedSharedNotebooks(userId: userId)
        } catch {
            print("Error loading topics: \(error)")
            topics = []
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

    /// Inserts image metadata for `note_attachments` using **existing columns only**:
    /// - **Pro / Premium**: `bucket` = `attachments`, `storage_path` = object key (contains `/`), bytes in Supabase Storage.
    /// - **Free + Photos asset id**: `bucket` = `photo_library`, `storage_path` = `localIdentifier`, thumbnail on disk `ph_thumb_<hash>.jpg`.
    /// - **Free otherwise**: `bucket` = `local`, `storage_path` = filename in app Documents.
    /// - **Legacy**: rows with `bucket` = `attachments` and a filename-only `storage_path` still resolve as on-device files.
    func createImageAttachment(
        for noteId: UUID,
        imageJPEGData: Data,
        assetLocalIdentifier: String?,
        reuseRelativePathIfAlreadyOnDisk: String? = nil
    ) async throws -> NoteAttachment {
        let session = try await supabase.auth.session
        let userId = session.user.id
        let tier = await MainActor.run { SubscriptionManager.shared.currentSubscriptionTier }
        let maxPhotos = tier.limits.maxPhotosPerNote
        let existingImages = try await imageAttachmentCount(forNoteId: noteId)
        if !tier.limits.isUnlimited(maxPhotos), existingImages >= maxPhotos {
            throw NSError(
                domain: "DataManager",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "This note already has the maximum number of photos for your plan."]
            )
        }

        let trimmedAsset = assetLocalIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAssetId = !(trimmedAsset?.isEmpty ?? true)

        switch tier {
        case .pro, .premium:
            let objectKey = "\(userId.uuidString.lowercased())/\(noteId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await supabase.storage
                .from(NoteAttachmentBuckets.supabase)
                .upload(
                    path: objectKey,
                    file: imageJPEGData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            let insert = NoteAttachmentInsert(
                note_id: noteId,
                uploaded_by: userId,
                kind: "image",
                bucket: NoteAttachmentBuckets.supabase,
                storage_path: objectKey,
                mime_type: "image/jpeg",
                size_bytes: imageJPEGData.count
            )
            return try await insertNoteAttachment(insert)

        case .free:
            if hasAssetId, let assetId = trimmedAsset {
                guard let thumbData = Self.thumbnailJPEGData(from: imageJPEGData) else {
                    throw NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not prepare image"])
                }
                let thumbName = "ph_thumb_\(Self.shortSHA256HexPrefix(assetId)).jpg"
                try thumbData.write(to: getDocumentsDirectory().appendingPathComponent(thumbName))
                let insert = NoteAttachmentInsert(
                    note_id: noteId,
                    uploaded_by: userId,
                    kind: "image",
                    bucket: NoteAttachmentBuckets.photoLibrary,
                    storage_path: assetId,
                    mime_type: "image/jpeg",
                    size_bytes: thumbData.count
                )
                return try await insertNoteAttachment(insert)
            }

            let relativeName: String
            if let reuse = reuseRelativePathIfAlreadyOnDisk,
               !reuse.isEmpty,
               !reuse.contains("/"),
               FileManager.default.fileExists(atPath: getDocumentsDirectory().appendingPathComponent(reuse).path) {
                relativeName = reuse
            } else {
                relativeName = "\(UUID().uuidString).jpg"
                try imageJPEGData.write(to: getDocumentsDirectory().appendingPathComponent(relativeName))
            }
            let insert = NoteAttachmentInsert(
                note_id: noteId,
                uploaded_by: userId,
                kind: "image",
                bucket: NoteAttachmentBuckets.localDevice,
                storage_path: relativeName,
                mime_type: "image/jpeg",
                size_bytes: imageJPEGData.count
            )
            return try await insertNoteAttachment(insert)
        }
    }

    /// Legacy helper: file already exists under Documents at `storagePath`. Applies tier rules via `createImageAttachment`.
    func createAttachment(for noteId: UUID, storagePath: String, mimeType: String?, sizeBytes: Int?, kind _: String) async throws -> NoteAttachment {
        let url = getDocumentsDirectory().appendingPathComponent(storagePath)
        let data = try Data(contentsOf: url)
        return try await createImageAttachment(
            for: noteId,
            imageJPEGData: data,
            assetLocalIdentifier: nil,
            reuseRelativePathIfAlreadyOnDisk: storagePath
        )
    }

    func imageAttachmentCount(forNoteId noteId: UUID) async throws -> Int {
        let attachments = try await getAttachments(forNoteId: noteId)
        return attachments.filter { $0.isImageLike }.count
    }

    func loadUIImage(for attachment: NoteAttachment) async -> UIImage? {
        guard attachment.isImageLike else { return nil }
        switch attachment.imageSemantics {
        case .localDeviceFile, .legacyLocalInAttachmentsBucket:
            let url = getDocumentsDirectory().appendingPathComponent(attachment.storage_path)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        case .photoLibraryReference:
            let thumbName = "ph_thumb_\(Self.shortSHA256HexPrefix(attachment.storage_path)).jpg"
            let thumbURL = getDocumentsDirectory().appendingPathComponent(thumbName)
            if let data = try? Data(contentsOf: thumbURL), let img = UIImage(data: data) {
                return img
            }
            return await loadUIImageFromPhotoLibrary(localIdentifier: attachment.storage_path)
        case .supabaseStorage:
            return await loadRemoteUIImage(for: attachment)
        }
    }

    private func insertNoteAttachment(_ insert: NoteAttachmentInsert) async throws -> NoteAttachment {
        let response = try await supabase
            .from("note_attachments")
            .insert(insert)
            .select()
            .single()
            .execute()
        return try JSONDecoder().decode(NoteAttachment.self, from: response.data)
    }

    private func loadRemoteUIImage(for attachment: NoteAttachment) async -> UIImage? {
        let cacheURL = getDocumentsDirectory().appendingPathComponent("remote_img_\(attachment.id.uuidString).jpg")
        if let cached = try? Data(contentsOf: cacheURL), let img = UIImage(data: cached) {
            return img
        }
        do {
            let data = try await supabase.storage
                .from(attachment.bucket)
                .download(path: attachment.storage_path)
            try? data.write(to: cacheURL)
            return UIImage(data: data)
        } catch {
            print("Remote image download failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadUIImageFromPhotoLibrary(localIdentifier: String) async -> UIImage? {
        let access: PHAccessLevel = .readWrite
        let status = PHPhotoLibrary.authorizationStatus(for: access)
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: access)
            guard newStatus == .authorized || newStatus == .limited else { return nil }
        } else if status != .authorized && status != .limited {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let results = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = results.firstObject else {
                continuation.resume(returning: nil)
                return
            }
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                let image = data.flatMap { UIImage(data: $0) }
                continuation.resume(returning: image)
            }
        }
    }

    private static func shortSHA256HexPrefix(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static func thumbnailJPEGData(from jpegData: Data, maxSide: CGFloat = 512, quality: CGFloat = 0.78) -> Data? {
        guard let image = UIImage(data: jpegData) else { return nil }
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return scaled.jpegData(compressionQuality: quality)
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

    // MARK: - Note sharing

    /// Reuses an active (non-revoked) link for the note or inserts one; requires sign-in and note ownership per RLS.
    func ensureActiveShareLink(forNoteId noteId: UUID) async throws -> UUID {
        let session = try await supabase.auth.session

        let listResponse = try await supabase
            .from("note_share_links")
            .select("token,revoked_at")
            .eq("note_id", value: noteId.uuidString)
            .execute()

        let rows = try JSONDecoder().decode([NoteShareLinkTokenRow].self, from: listResponse.data)
        if let active = rows.first(where: { $0.revoked_at == nil }) {
            return active.token
        }

        let insert = NoteShareLinkInsert(note_id: noteId, created_by: session.user.id)
        let insertResponse = try await supabase
            .from("note_share_links")
            .insert(insert)
            .select("token")
            .single()
            .execute()

        struct TokenOnly: Codable { let token: UUID }
        let row = try JSONDecoder().decode(TokenOnly.self, from: insertResponse.data)
        return row.token
    }

    /// Public payload for a valid, non-revoked share token (`get_note_by_share_token`). Callable with anon or user JWT.
    func fetchSharedNotePayload(shareToken: UUID) async throws -> SharedNotePayload? {
        let response = try await supabase
            .rpc("get_note_by_share_token", params: ShareTokenRPCParams(p_token: shareToken))
            .execute()

        let raw = response.data
        if raw.isEmpty { return nil }
        if let str = String(data: raw, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           str == "null" {
            return nil
        }

        return try JSONDecoder().decode(SharedNotePayload.self, from: raw)
    }

    /// Reuses an active (non-revoked) notebook link or inserts one; owner only per RLS.
    func ensureActiveTopicShareLink(forTopicId topicId: UUID) async throws -> UUID {
        let session = try await supabase.auth.session

        let listResponse = try await supabase
            .from("topic_share_links")
            .select("token,revoked_at")
            .eq("topic_id", value: topicId.uuidString)
            .execute()

        let rows = try JSONDecoder().decode([TopicShareLinkTokenRow].self, from: listResponse.data)
        if let active = rows.first(where: { $0.revoked_at == nil }) {
            return active.token
        }

        let insert = TopicShareLinkInsert(topic_id: topicId, created_by: session.user.id)
        let insertResponse = try await supabase
            .from("topic_share_links")
            .insert(insert)
            .select("token")
            .single()
            .execute()

        struct TokenOnly: Codable { let token: UUID }
        let row = try JSONDecoder().decode(TokenOnly.self, from: insertResponse.data)
        return row.token
    }

    /// Full notebook tree for a valid share token (`get_notebook_by_share_token`).
    func fetchSharedNotebookPayload(shareToken: UUID) async throws -> SharedNotebookPayload? {
        let response = try await supabase
            .rpc("get_notebook_by_share_token", params: ShareTokenRPCParams(p_token: shareToken))
            .execute()

        let raw = response.data
        if raw.isEmpty { return nil }
        if let str = String(data: raw, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           str == "null" {
            return nil
        }

        return try JSONDecoder().decode(SharedNotebookPayload.self, from: raw)
    }
}
