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

// MARK: - Topic Preview View
struct TopicPreviewView: View {
    let topic: Topic
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    @EnvironmentObject var searchState: SearchState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(.appAccent)
                    }
                    
                    Text(topic.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Subtopics Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(topic.subtopics) { subtopic in
                        NavigationLink(destination: SubtopicPreviewView(subtopic: subtopic, topic: topic, isPresented: $isPresented)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "folder.fill.badge.person.crop")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                                
                                Text(subtopic.title)
                                    .font(.headline)
                                    .foregroundColor(.appText)
                                    .lineLimit(2)
                                
                                Text("\(subtopic.notes.count) notes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appCardBackground)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Subtopic Preview View
struct SubtopicPreviewView: View {
    let subtopic: Subtopic
    let topic: Topic
    @Binding var isPresented: Bool
    @EnvironmentObject var searchState: SearchState
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(.appAccent)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(topic.title)
                            .font(.subheadline)
                            .foregroundColor(.appAccent)
                        Text(subtopic.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.appText)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Notes Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(subtopic.notes) { note in
                        Button(action: {
                            noteDisplayState.currentNote = note
                            noteDisplayState.currentTopic = topic
                            noteDisplayState.currentSubtopic = subtopic
                            noteDisplayState.isShowingNote = true
                            isPresented = false
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let photoURL = note.photoURL {
                                    AsyncImage(url: photoURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 120)
                                            .clipped()
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 120)
                                    }
                                    .cornerRadius(8)
                                } else {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 24))
                                        .foregroundColor(.appAccent)
                                        .frame(height: 120)
                                }
                                
                                Text(note.title)
                                    .font(.headline)
                                    .foregroundColor(.appText)
                                    .lineLimit(2)
                                
                                Text(note.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.appCardBackground)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
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
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Notebook")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
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
        .background(Color.appBackground)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 120)
        }
        .environmentObject(searchState)
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
        NavigationLink(destination: TopicPreviewView(topic: topic, isPresented: $isPresented)) {
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
