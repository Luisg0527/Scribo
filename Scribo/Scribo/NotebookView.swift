import SwiftUI

// MARK: - Search State
class SearchState: ObservableObject {
    @Published var searchText: String = ""
}

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

struct Note: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var photoURL: URL?
    var date: Date
}

// MARK: - Highlighted Text View
struct HighlightedText: View {
    let text: String
    let searchText: String
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            let parts = text.components(separatedBy: searchText)
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    Text(part)
                    if index < parts.count - 1 {
                        Text(searchText)
                            .foregroundColor(.white)
                            .background(Color.appAccent)
                    }
                }
            }
        }
    }
}

// MARK: - Notebook View
struct NotebookView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchState = SearchState()
    @Binding var isPresented: Bool
    @State private var topics: [Topic] = [
        Topic(title: "Computer Science", subtopics: [
            Subtopic(title: "Data Structures", notes: [
                Note(title: "Binary Trees", content: "A tree data structure where each node has at most two children.", date: Date()),
                Note(title: "Linked Lists", content: "A linear data structure where elements are stored in nodes.", date: Date())
            ], date: Date())
        ], date: Date()),
        Topic(title: "Mathematics", subtopics: [
            Subtopic(title: "Calculus", notes: [
                Note(title: "Derivatives", content: "The rate of change of a function.", date: Date())
            ], date: Date())
        ], date: Date())
    ]
    
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var selectedNote: Note?
    @State private var isShowingNewTopicSheet = false
    
    var filteredTopics: [Topic] {
        if searchState.searchText.isEmpty {
            return topics
        }
        
        return topics.compactMap { topic in
            let matchingSubtopics = topic.subtopics.compactMap { subtopic -> Subtopic? in
                let matchingNotes = subtopic.notes.filter { note in
                    note.title.localizedCaseInsensitiveContains(searchState.searchText) ||
                    note.content.localizedCaseInsensitiveContains(searchState.searchText)
                }
                
                if !matchingNotes.isEmpty || subtopic.title.localizedCaseInsensitiveContains(searchState.searchText) {
                    return Subtopic(
                        title: subtopic.title,
                        notes: matchingNotes,
                        date: subtopic.date
                    )
                }
                return nil
            }
            
            if !matchingSubtopics.isEmpty || topic.title.localizedCaseInsensitiveContains(searchState.searchText) {
                return Topic(
                    title: topic.title,
                    subtopics: matchingSubtopics,
                    date: topic.date
                )
            }
            return nil
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search notes...", text: $searchState.searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchState.searchText.isEmpty {
                        Button(action: {
                            searchState.searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color.appCardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // List of Topics
                List {
                    ForEach(filteredTopics) { topic in
                        TopicRow(topic: topic, selectedTopic: $selectedTopic, selectedSubtopic: $selectedSubtopic, selectedNote: $selectedNote, isPresented: $isPresented)
                            .environmentObject(searchState)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Notebook")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingNewTopicSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewTopicSheet) {
                NewTopicView(topics: $topics)
            }
        }
    }
}

struct TopicRow: View {
    let topic: Topic
    @Binding var selectedTopic: Topic?
    @Binding var selectedSubtopic: Subtopic?
    @Binding var selectedNote: Note?
    @State private var isExpanded: Bool = false
    @EnvironmentObject var searchState: SearchState
    @Binding var isPresented: Bool
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { selectedTopic?.id == topic.id || isExpanded },
                set: { if $0 { selectedTopic = topic } else { selectedTopic = nil } }
            )
        ) {
            ForEach(topic.subtopics) { subtopic in
                SubtopicRow(subtopic: subtopic, selectedSubtopic: $selectedSubtopic, selectedNote: $selectedNote, isPresented: $isPresented, topic: topic)
            }
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.appAccent)
                HighlightedText(text: topic.title, searchText: searchState.searchText)
                    .font(.headline)
                Spacer()
                Text(topic.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            if !searchState.searchText.isEmpty {
                isExpanded = topic.subtopics.contains { subtopic in
                    subtopic.title.localizedCaseInsensitiveContains(searchState.searchText) ||
                    subtopic.notes.contains { note in
                        note.title.localizedCaseInsensitiveContains(searchState.searchText) ||
                        note.content.localizedCaseInsensitiveContains(searchState.searchText)
                    }
                }
            }
        }
    }
}

struct SubtopicRow: View {
    let subtopic: Subtopic
    @Binding var selectedSubtopic: Subtopic?
    @Binding var selectedNote: Note?
    @State private var isExpanded: Bool = false
    @EnvironmentObject var searchState: SearchState
    @Binding var isPresented: Bool
    let topic: Topic
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { selectedSubtopic?.id == subtopic.id || isExpanded },
                set: { if $0 { selectedSubtopic = subtopic } else { selectedSubtopic = nil } }
            )
        ) {
            ForEach(subtopic.notes) { note in
                NoteRow(note: note, selectedNote: $selectedNote, isPresented: $isPresented, topic: topic, subtopic: subtopic)
            }
        } label: {
            HStack {
                Image(systemName: "folder.fill.badge.person.crop")
                    .foregroundColor(.appAccent)
                HighlightedText(text: subtopic.title, searchText: searchState.searchText)
                    .font(.subheadline)
                Spacer()
                Text(subtopic.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.leading)
        .onAppear {
            if !searchState.searchText.isEmpty {
                isExpanded = subtopic.title.localizedCaseInsensitiveContains(searchState.searchText) ||
                    subtopic.notes.contains { note in
                        note.title.localizedCaseInsensitiveContains(searchState.searchText) ||
                        note.content.localizedCaseInsensitiveContains(searchState.searchText)
                    }
            }
        }
    }
}

struct NoteRow: View {
    let note: Note
    @Binding var selectedNote: Note?
    @EnvironmentObject var searchState: SearchState
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @Binding var isPresented: Bool
    let topic: Topic
    let subtopic: Subtopic
    
    var body: some View {
        Button(action: {
            noteDisplayState.currentNote = note
            noteDisplayState.currentTopic = topic
            noteDisplayState.currentSubtopic = subtopic
            noteDisplayState.isShowingNote = true
            isPresented = false
        }) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.appAccent)
                HighlightedText(text: note.title, searchText: searchState.searchText)
                    .font(.subheadline)
                Spacer()
                Text(note.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.leading, 32)
    }
}

struct NoteDetailView: View {
    let note: Note
    @EnvironmentObject var searchState: SearchState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let photoURL = note.photoURL {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                }
                
                HighlightedText(text: note.title, searchText: searchState.searchText)
                    .font(.title)
                    .fontWeight(.bold)
                
                HighlightedText(text: note.content, searchText: searchState.searchText)
                    .font(.body)
                
                Text(note.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NewTopicView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var topics: [Topic]
    @State private var title = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Topic Title", text: $title)
            }
            .navigationTitle("New Topic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    let newTopic = Topic(title: title, subtopics: [], date: Date())
                    topics.append(newTopic)
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

struct NotebookView_Previews: PreviewProvider {
    static var previews: some View {
        NotebookView(isPresented: .constant(true))
    }
}
