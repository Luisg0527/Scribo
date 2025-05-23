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
    @State private var selectedSubtopic: Subtopic?
    @State private var isShowingEditSubtopicSheet = false
    
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
        .sheet(isPresented: $isShowingEditSubtopicSheet) {
            if let subtopic = selectedSubtopic {
                EditSubtopicView(subtopic: subtopic, topic: topic, dataManager: dataManager)
            }
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
            
            Button(action: {
                selectedSubtopic = subtopic
                isShowingEditSubtopicSheet = true
            }) {
                Label("Edit Subtopic", systemImage: "pencil")
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
            if let attachmentUrl = note.attachment_url {
                let fileURL = getDocumentsDirectory().appendingPathComponent(attachmentUrl)
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 120)
                                            .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "note.text")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                                            .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                }
                                } else {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 24))
                    .foregroundColor(.gray)
                                        .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
                                }
                                
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func noteTitle(_ note: Note) -> some View {
                                Text(note.title)
                                    .font(.headline)
                                    .foregroundColor(.appText)
                                    .lineLimit(2)
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
    @State private var isShowingEditTopicSheet = false
    @State private var isShowingEditSubtopicSheet = false
    @State private var expandedTopics: Set<UUID> = []
    @State private var expandedSubtopics: Set<UUID> = []

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
                        id: subtopic.id,
                        topic_id: subtopic.topic_id,
                        title: subtopic.title,
                        notes: matchingNotes,
                        created_at: subtopic.created_at,
                        updated_at: subtopic.updated_at
                    )
                }
                return nil
            }
            if !matchingSubtopics.isEmpty || topic.title.localizedCaseInsensitiveContains(searchState.searchText) {
                return Topic(
                    id: topic.id,
                    user_id: topic.user_id,
                    title: topic.title,
                    subtopics: matchingSubtopics,
                    created_at: topic.created_at,
                    updated_at: topic.updated_at
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

                // Hierarchical Tree
                List {
                    ForEach(filteredTopics) { topic in
                        TopicRow(
                            topic: topic,
                            selectedTopic: $selectedTopic,
                            selectedSubtopic: $selectedSubtopic,
                            selectedNote: $selectedNote,
                            isPresented: $isPresented,
                            dataManager: dataManager,
                            subtopicToDelete: $subtopicToDelete,
                            noteToDelete: $noteToDelete,
                            isExpanded: expandedTopics.contains(topic.id),
                            onExpandChange: { expanded, topicId in
                                if expanded {
                                    expandedTopics.insert(topicId)
                                } else {
                                    expandedTopics.remove(topicId)
                                }
                            },
                            expandedSubtopics: $expandedSubtopics,
                            searchText: searchState.searchText,
                            isShowingNewTopicSheet: $isShowingNewTopicSheet,
                            isShowingEditTopicSheet: $isShowingEditTopicSheet,
                            topicToDelete: $topicToDelete,
                            isShowingEditSubtopicSheet: $isShowingEditSubtopicSheet,
                            isShowingNewSubtopicSheet: $isShowingNewSubtopicSheet
                        )
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
                    NewSubtopicView(topic: topic, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $isShowingNewNoteSheet) {
                if let topic = selectedTopic, let subtopic = selectedSubtopic {
                    NewNoteView(topic: topic, subtopic: subtopic, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $isShowingEditTopicSheet) {
                if let topic = selectedTopic {
                    EditTopicView(topic: topic, dataManager: dataManager)
                }
            }
            .sheet(isPresented: $isShowingEditSubtopicSheet) {
                if let topic = selectedTopic, let subtopic = selectedSubtopic {
                    EditSubtopicView(subtopic: subtopic, topic: topic, dataManager: dataManager)
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
        .onChange(of: searchState.searchText) { newValue in
            if newValue.isEmpty {
                expandedTopics.removeAll()
                expandedSubtopics.removeAll()
            } else {
                // Expand all topics and subtopics that match the search
                var newExpandedTopics: Set<UUID> = []
                var newExpandedSubtopics: Set<UUID> = []
                for topic in filteredTopics {
                    let topicMatches = topic.title.localizedCaseInsensitiveContains(newValue)
                    var topicShouldExpand = topicMatches
                    for subtopic in topic.subtopics {
                        let subtopicMatches = subtopic.title.localizedCaseInsensitiveContains(newValue)
                        let noteMatches = subtopic.notes.contains { note in
                            note.title.localizedCaseInsensitiveContains(newValue) ||
                            note.content.localizedCaseInsensitiveContains(newValue)
                        }
                        if subtopicMatches || noteMatches {
                            topicShouldExpand = true
                            newExpandedSubtopics.insert(subtopic.id)
                        }
                    }
                    if topicShouldExpand {
                        newExpandedTopics.insert(topic.id)
                    }
                }
                expandedTopics = newExpandedTopics
                expandedSubtopics = newExpandedSubtopics
            }
        }
    }
}

struct TopicRow: View {
    let topic: Topic
    @Binding var selectedTopic: Topic?
    @Binding var selectedSubtopic: Subtopic?
    @Binding var selectedNote: Note?
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @Binding var subtopicToDelete: (Topic, Subtopic)?
    @Binding var noteToDelete: (Topic, Subtopic, Note)?
    var isExpanded: Bool
    var onExpandChange: (Bool, UUID) -> Void
    @Binding var expandedSubtopics: Set<UUID>
    var searchText: String
    @Binding var isShowingNewTopicSheet: Bool
    @Binding var isShowingEditTopicSheet: Bool
    @Binding var topicToDelete: Topic?
    @Binding var isShowingEditSubtopicSheet: Bool
    @Binding var isShowingNewSubtopicSheet: Bool
    @EnvironmentObject var searchState: SearchState
    @State private var localIsExpanded: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { newValue in
                localIsExpanded = newValue
                onExpandChange(newValue, topic.id)
            }
        )) {
            ForEach(topic.subtopics) { subtopic in
                SubtopicRow(
                    subtopic: subtopic,
                    topic: topic,
                    selectedSubtopic: $selectedSubtopic,
                    selectedNote: $selectedNote,
                    isPresented: $isPresented,
                    dataManager: dataManager,
                    subtopicToDelete: $subtopicToDelete,
                    noteToDelete: $noteToDelete,
                    isExpanded: expandedSubtopics.contains(subtopic.id),
                    onExpandChange: { expanded, subtopicId in
                        if expanded {
                            expandedSubtopics.insert(subtopicId)
                        } else {
                            expandedSubtopics.remove(subtopicId)
                        }
                    },
                    searchText: searchText,
                    isShowingEditSubtopicSheet: $isShowingEditSubtopicSheet,
                    isShowingNewSubtopicSheet: $isShowingNewSubtopicSheet,
                    selectedTopic: $selectedTopic
                )
                .padding(.leading, 16)
            }
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.appAccent)
                HighlightedText(text: topic.title, searchText: searchText)
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 6)
            .contextMenu {
                Button(action: {
                    selectedTopic = topic
                    isShowingNewSubtopicSheet = true
                }) {
                    Label("Add Subtopic", systemImage: "folder.badge.plus")
                }
                Button(action: {
                    selectedTopic = topic
                    isShowingEditTopicSheet = true
                }) {
                    Label("Edit Topic", systemImage: "pencil")
                }
                Button(role: .destructive, action: {
                    selectedTopic = topic
                    topicToDelete = topic
                }) {
                    Label("Delete Topic", systemImage: "trash")
                }
            }
        }
    }
}

struct SubtopicRow: View {
    let subtopic: Subtopic
    let topic: Topic
    @Binding var selectedSubtopic: Subtopic?
    @Binding var selectedNote: Note?
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @Binding var subtopicToDelete: (Topic, Subtopic)?
    @Binding var noteToDelete: (Topic, Subtopic, Note)?
    var isExpanded: Bool
    var onExpandChange: (Bool, UUID) -> Void
    var searchText: String
    @Binding var isShowingEditSubtopicSheet: Bool
    @Binding var isShowingNewSubtopicSheet: Bool
    @Binding var selectedTopic: Topic?
    @EnvironmentObject var searchState: SearchState
    @State private var localIsExpanded: Bool = false
    @State private var isActive = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { isExpanded },
            set: { newValue in
                localIsExpanded = newValue
                onExpandChange(newValue, subtopic.id)
            }
        )) {
            ForEach(subtopic.notes) { note in
                NoteRow(
                    note: note,
                    topic: topic,
                    subtopic: subtopic,
                    selectedNote: $selectedNote,
                    isPresented: $isPresented,
                    dataManager: dataManager,
                    noteToDelete: $noteToDelete
                )
                .padding(.leading, 16)
            }
        } label: {
            NavigationLink(
                destination: SubtopicPreviewView(subtopic: subtopic, topic: topic, isPresented: $isPresented, dataManager: dataManager),
                isActive: $isActive
            ) {
                HStack {
                    Image(systemName: "folder.fill.badge.person.crop")
                        .foregroundColor(.appAccent)
                    HighlightedText(text: subtopic.title, searchText: searchText)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSubtopic = subtopic
                    selectedTopic = topic
                    isActive = true
                }
            }
            .buttonStyle(PlainButtonStyle())
            .contextMenu {
                Button(action: {
                    selectedSubtopic = subtopic
                    selectedTopic = topic
                    isShowingEditSubtopicSheet = true
                }) {
                    Label("Edit Subtopic", systemImage: "pencil")
                }
                Button(role: .destructive, action: {
                    subtopicToDelete = (topic, subtopic)
                }) {
                    Label("Delete Subtopic", systemImage: "trash")
                }
            }
        }
    }
}

struct NoteRow: View {
    let note: Note
    let topic: Topic
    let subtopic: Subtopic
    @Binding var selectedNote: Note?
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @Binding var noteToDelete: (Topic, Subtopic, Note)?
    @EnvironmentObject var searchState: SearchState
    @EnvironmentObject var noteDisplayState: NoteDisplayState

    var body: some View {
        HStack {
            Image(systemName: "note.text")
                .foregroundColor(.appAccent)
            HighlightedText(text: note.title, searchText: searchState.searchText)
                .font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            noteDisplayState.currentNote = note
            noteDisplayState.currentTopic = topic
            noteDisplayState.currentSubtopic = subtopic
            noteDisplayState.isShowingNote = true
            isPresented = false
        }
        .contextMenu {
            Button(role: .destructive, action: {
                noteToDelete = (topic, subtopic, note)
            }) {
                Label("Delete Note", systemImage: "trash")
            }
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    @EnvironmentObject var searchState: SearchState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let attachmentUrl = note.attachment_url {
                    let fileURL = getDocumentsDirectory().appendingPathComponent(attachmentUrl)
                    if let image = UIImage(contentsOfFile: fileURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    }
                }
                
                HighlightedText(text: note.title, searchText: searchState.searchText)
                    .font(.title)
                    .fontWeight(.bold)
                
                HighlightedText(text: note.content, searchText: searchState.searchText)
                    .font(.body)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

struct NewTopicView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
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
                    Task {
                        await saveTopic()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveTopic() async {
        isSaving = true
        do {
            _ = try await dataManager.addTopic(title: title)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct NewSubtopicView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
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
                    Task {
                        await saveSubtopic()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveSubtopic() async {
        isSaving = true
        do {
            _ = try await dataManager.addSubtopic(to: topic, title: title)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct NewNoteView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    let subtopic: Subtopic
    @ObservedObject var dataManager: DataManager
    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
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
                    Task {
                        await saveNote()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveNote() async {
        isSaving = true
        do {
            _ = try await dataManager.addNote(to: subtopic, in: topic, title: title, content: content)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct EditTopicView: View {
    @Environment(\.dismiss) var dismiss
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(topic: Topic, dataManager: DataManager) {
        self.topic = topic
        self.dataManager = dataManager
        self._title = State(initialValue: topic.title)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Topic Title", text: $title)
            }
            .navigationTitle("Edit Topic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await saveTopic()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveTopic() async {
        isSaving = true
        do {
            try await dataManager.updateTopic(topic, newTitle: title)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct EditSubtopicView: View {
    @Environment(\.dismiss) var dismiss
    let subtopic: Subtopic
    let topic: Topic
    @ObservedObject var dataManager: DataManager
    @State private var title: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(subtopic: Subtopic, topic: Topic, dataManager: DataManager) {
        self.subtopic = subtopic
        self.topic = topic
        self.dataManager = dataManager
        self._title = State(initialValue: subtopic.title)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Subtopic Title", text: $title)
            }
            .navigationTitle("Edit Subtopic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        await saveSubtopic()
                    }
                }
                .disabled(title.isEmpty || isSaving)
            )
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveSubtopic() async {
        isSaving = true
        do {
            try await dataManager.updateSubtopic(subtopic, in: topic, newTitle: title)
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        isSaving = false
    }
}

struct NotebookView_Previews: PreviewProvider {
    static var previews: some View {
        NotebookView(isPresented: .constant(true))
    }
}
