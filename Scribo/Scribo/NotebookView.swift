import SwiftUI

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
    @ObservedObject var dataManager: DataManager
    @State private var subtopicToDelete: (Topic, Subtopic)?
    @State private var noteToDelete: (Topic, Subtopic, Note)?
    @State private var isShowingNewSubtopicSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                subtopicsGridView
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                addSubtopicButton
            }
        }
        .sheet(isPresented: $isShowingNewSubtopicSheet) {
            NewSubtopicView(topic: topic, dataManager: dataManager)
        }
        .alert("Delete Subtopic", isPresented: .init(
            get: { subtopicToDelete != nil },
            set: { if !$0 { subtopicToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                subtopicToDelete = nil
            }
            Button("Delete", role: .destructive) {
                // Delete subtopic action
                subtopicToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this subtopic? This will also delete all its notes.")
        }
    }
    
    private var headerView: some View {
                HStack {
                    Text(topic.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)
                    Spacer()
                }
                .padding(.horizontal)
    }
                
    private var subtopicsGridView: some View {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(topic.subtopics) { subtopic in
                subtopicCard(subtopic)
            }
        }
        .padding(.horizontal)
    }
    
    private func subtopicCard(_ subtopic: Subtopic) -> some View {
        NavigationLink(destination: SubtopicPreviewView(subtopic: subtopic, topic: topic, isPresented: $isPresented, dataManager: dataManager)) {
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
                        .contextMenu {
                            Button(action: {
                                // Add note action
                            }) {
                                Label("Add Note", systemImage: "note.text.badge.plus")
                            }
                            
                            Button(role: .destructive, action: {
                                subtopicToDelete = (topic, subtopic)
                            }) {
                                Label("Delete Subtopic", systemImage: "trash")
                            }
                        }
                    }
    
    private var addSubtopicButton: some View {
                Button(action: {
                    isShowingNewSubtopicSheet = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.appAccent)
        }
    }
}

// MARK: - Subtopic Preview View
struct SubtopicPreviewView: View {
    let subtopic: Subtopic
    let topic: Topic
    @Binding var isPresented: Bool
    @EnvironmentObject var searchState: SearchState
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @ObservedObject var dataManager: DataManager
    @State private var noteToDelete: (Topic, Subtopic, Note)?
    @State private var isShowingNewNoteSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                notesGridView
            }
            .padding(.vertical)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                addNoteButton
            }
        }
        .sheet(isPresented: $isShowingNewNoteSheet) {
            NewNoteView(topic: topic, subtopic: subtopic, dataManager: dataManager)
        }
        .alert("Delete Note", isPresented: .init(
            get: { noteToDelete != nil },
            set: { if !$0 { noteToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let (topic, subtopic, note) = noteToDelete {
                    dataManager.deleteNote(note, from: subtopic, from: topic)
                }
                noteToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this note?")
        }
    }
    
    private var headerView: some View {
                HStack {
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
    }
                
    private var notesGridView: some View {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(subtopic.notes) { note in
                noteCard(note)
            }
        }
        .padding(.horizontal)
    }
    
    private func noteCard(_ note: Note) -> some View {
                        Button(action: {
                            noteDisplayState.currentNote = note
                            noteDisplayState.currentTopic = topic
                            noteDisplayState.currentSubtopic = subtopic
                            noteDisplayState.isShowingNote = true
                            isPresented = false
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                noteImage(note)
                noteTitle(note)
                noteDate(note)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.appCardBackground)
            .cornerRadius(12)
        }
        .contextMenu {
            Button(role: .destructive, action: {
                noteToDelete = (topic, subtopic, note)
            }) {
                Label("Delete Note", systemImage: "trash")
            }
        }
    }
    
    private func noteImage(_ note: Note) -> some View {
        Group {
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
        }
                                }
                                
    private func noteTitle(_ note: Note) -> some View {
                                Text(note.title)
                                    .font(.headline)
                                    .foregroundColor(.appText)
                                    .lineLimit(2)
    }
                                
    private func noteDate(_ note: Note) -> some View {
                                Text(note.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
    
    private var addNoteButton: some View {
                Button(action: {
                    isShowingNewNoteSheet = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.appAccent)
        }
    }
}

// MARK: - Notebook View
struct NotebookView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchState = SearchState()
    @StateObject private var dataManager = DataManager()
    @Binding var isPresented: Bool
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var selectedNote: Note?
    @State private var isShowingNewTopicSheet = false
    @State private var isShowingNewSubtopicSheet = false
    @State private var isShowingNewNoteSheet = false
    @State private var topicToDelete: Topic?
    @State private var subtopicToDelete: (Topic, Subtopic)?
    @State private var noteToDelete: (Topic, Subtopic, Note)?
    
    var filteredTopics: [Topic] {
        if searchState.searchText.isEmpty {
            return dataManager.topics
        }
        
        return dataManager.topics.compactMap { topic in
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
                                .font(.system(size: 20))
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
                        NavigationLink(destination: TopicPreviewView(topic: topic, isPresented: $isPresented, dataManager: dataManager)) {
                            TopicRow(topic: topic, 
                                   selectedTopic: $selectedTopic, 
                                   selectedSubtopic: $selectedSubtopic, 
                                   selectedNote: $selectedNote, 
                                   isPresented: $isPresented,
                                   dataManager: dataManager)
                        }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    topicToDelete = topic
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    selectedTopic = topic
                                    isShowingNewSubtopicSheet = true
                                }) {
                                    Label("Add Subtopic", systemImage: "folder.badge.plus")
                                }
                                
                                Button(role: .destructive, action: {
                                    topicToDelete = topic
                                }) {
                                    Label("Delete Topic", systemImage: "trash")
                                }
                            }
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
                            .font(.system(size: 20))
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
                NewTopicView(dataManager: dataManager)
            }
            .sheet(isPresented: $isShowingNewSubtopicSheet) {
                if let topic = selectedTopic {
                    NewSubtopicView(topic: topic, dataManager: DataManager())
                }
            }
            .sheet(isPresented: $isShowingNewNoteSheet) {
                if let topic = selectedTopic, let subtopic = selectedSubtopic {
                    NewNoteView(topic: topic, subtopic: subtopic, dataManager: dataManager)
                }
            }
            .alert("Delete Topic", isPresented: .init(
                get: { topicToDelete != nil },
                set: { if !$0 { topicToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    topicToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let topic = topicToDelete {
                        dataManager.deleteTopic(topic)
                    }
                    topicToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this topic? This will also delete all its subtopics and notes.")
            }
            .alert("Delete Subtopic", isPresented: .init(
                get: { subtopicToDelete != nil },
                set: { if !$0 { subtopicToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    subtopicToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let (topic, subtopic) = subtopicToDelete {
                        dataManager.deleteSubtopic(subtopic, from: topic)
                    }
                    subtopicToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this subtopic? This will also delete all its notes.")
            }
            .alert("Delete Note", isPresented: .init(
                get: { noteToDelete != nil },
                set: { if !$0 { noteToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    noteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let (topic, subtopic, note) = noteToDelete {
                        dataManager.deleteNote(note, from: subtopic, from: topic)
                    }
                    noteToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this note?")
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
    @State private var isShowingNewSubtopicSheet = false
    @State private var isShowingNewNoteSheet = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @ObservedObject var dataManager: DataManager
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded
        ) {
            ForEach(topic.subtopics) { subtopic in
                DisclosureGroup {
                    ForEach(subtopic.notes) { note in
                        NoteRow(note: note, selectedNote: $selectedNote, isPresented: $isPresented, topic: topic, subtopic: subtopic)
                    }
                } label: {
                    NavigationLink(destination: SubtopicPreviewView(subtopic: subtopic, topic: topic, isPresented: $isPresented, dataManager: dataManager)) {
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
                }
                .padding(.leading)
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
        .contextMenu {
            Button(action: {
                selectedTopic = topic
                isShowingNewSubtopicSheet = true
            }) {
                Label("Add Subtopic", systemImage: "folder.badge.plus")
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
    @State private var isShowingNewNoteSheet = false
    @Binding var subtopicToDelete: (Topic, Subtopic)?
    @Binding var noteToDelete: (Topic, Subtopic, Note)?
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { selectedSubtopic?.id == subtopic.id || isExpanded },
                set: { if $0 { selectedSubtopic = subtopic } else { selectedSubtopic = nil } }
            )
        ) {
            ForEach(subtopic.notes) { note in
                NoteRow(note: note, selectedNote: $selectedNote, isPresented: $isPresented, topic: topic, subtopic: subtopic)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            noteToDelete = (topic, subtopic, note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                subtopicToDelete = (topic, subtopic)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(action: {
                selectedSubtopic = subtopic
                isShowingNewNoteSheet = true
            }) {
                Label("Add Note", systemImage: "note.text.badge.plus")
            }
            
            Button(role: .destructive, action: {
                subtopicToDelete = (topic, subtopic)
            }) {
                Label("Delete Subtopic", systemImage: "trash")
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
    @ObservedObject var dataManager: DataManager
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
                    dataManager.addTopic(title: title)
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

struct NewSubtopicView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Subtopic Title", text: $title)
            }
            .navigationTitle("New Subtopic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    dataManager.addSubtopic(to: topic, title: title)
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

struct NewNoteView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    let subtopic: Subtopic
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var content = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Note Title", text: $title)
                TextEditor(text: $content)
                    .frame(height: 200)
            }
            .navigationTitle("New Note")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    dataManager.addNote(to: subtopic, in: topic, title: title, content: content)
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
