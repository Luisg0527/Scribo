import Foundation
import SwiftUI
import Supabase

// MARK: - Database Models
struct TopicRecord: Codable {
    let id: UUID
    let title: String
    let date: Date
    
    init(title: String, date: Date) {
        self.id = UUID()
        self.title = title
        self.date = date
    }
}

struct SubtopicRecord: Codable {
    let id: UUID
    let topic_id: UUID
    let title: String
    let date: Date
    
    init(topic_id: UUID, title: String, date: Date) {
        self.id = UUID()
        self.topic_id = topic_id
        self.title = title
        self.date = date
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
                let newTopic = TopicRecord(
                    title: title,
                    date: Date()
                )
                
                let response = try await supabase
                    .from("topics")
                    .insert(newTopic)
                    .select()
                    .execute()
                
                let topicRecord = try JSONDecoder().decode(TopicRecord.self, from: response.data)
                let topic = Topic(
                    title: topicRecord.title,
                    subtopics: [],
                    date: topicRecord.date
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
                    title: newTitle,
                    date: topic.date
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
                let newSubtopic = SubtopicRecord(
                    topic_id: topic.id,
                    title: title,
                    date: Date()
                )
                
                let response = try await supabase
                    .from("subtopics")
                    .insert(newSubtopic)
                    .select()
                    .execute()
                
                let subtopicRecord = try JSONDecoder().decode(SubtopicRecord.self, from: response.data)
                let subtopic = Subtopic(
                    title: subtopicRecord.title,
                    notes: [],
                    date: subtopicRecord.date
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
                    topic_id: topic.id,
                    title: newTitle,
                    date: subtopic.date
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
                try await supabase
                    .from("subtopics")
                    .delete()
                    .eq("id", value: subtopic.id.uuidString)
                    .execute()
                
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
    func addNote(to subtopic: Subtopic, in topic: Topic, title: String, content: String, photoURL: URL? = nil) {
        Task {
            do {
                let newNote = NoteRecord(
                    topic_id: topic.id,
                    subtopic_id: subtopic.id,
                    title: title,
                    content: content,
                    photo_url: photoURL?.absoluteString,
                    date: Date()
                )
                
                let response = try await supabase
                    .from("notes")
                    .insert(newNote)
                    .select()
                    .execute()
                
                let noteRecord = try JSONDecoder().decode(NoteRecord.self, from: response.data)
                let note = Note(
                    title: noteRecord.title,
                    content: noteRecord.content,
                    photoURL: noteRecord.photo_url.flatMap { URL(string: $0) },
                    date: noteRecord.date
                )
                await MainActor.run {
                    if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
                       let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }) {
                        topics[topicIndex].subtopics[subtopicIndex].notes.append(note)
                    }
                }
            } catch {
                print("Error adding note: \(error)")
            }
        }
    }
    
    func updateNote(_ note: Note, in subtopic: Subtopic, in topic: Topic, newTitle: String? = nil, newContent: String? = nil, newPhotoURL: URL? = nil) {
        Task {
            do {
                let updateData = NoteRecord(
                    topic_id: topic.id,
                    subtopic_id: subtopic.id,
                    title: newTitle ?? note.title,
                    content: newContent ?? note.content,
                    photo_url: newPhotoURL?.absoluteString ?? note.photoURL?.absoluteString,
                    date: note.date
                )
                
                try await supabase
                    .from("notes")
                    .update(updateData)
                    .eq("id", value: note.id.uuidString)
                    .execute()
                
                await MainActor.run {
                    if let topicIndex = topics.firstIndex(where: { $0.id == topic.id }),
                       let subtopicIndex = topics[topicIndex].subtopics.firstIndex(where: { $0.id == subtopic.id }),
                       let noteIndex = topics[topicIndex].subtopics[subtopicIndex].notes.firstIndex(where: { $0.id == note.id }) {
                        if let newTitle = newTitle {
                            topics[topicIndex].subtopics[subtopicIndex].notes[noteIndex].title = newTitle
                        }
                        if let newContent = newContent {
                            topics[topicIndex].subtopics[subtopicIndex].notes[noteIndex].content = newContent
                        }
                        if let newPhotoURL = newPhotoURL {
                            topics[topicIndex].subtopics[subtopicIndex].notes[noteIndex].photoURL = newPhotoURL
                        }
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
                .select("*, subtopics(*, notes(*))")
                .execute()
            
            let topics = try JSONDecoder().decode([Topic].self, from: response.data)
            self.topics = topics
        } catch {
            print("Error loading topics: \(error)")
        }
    }
} 
 