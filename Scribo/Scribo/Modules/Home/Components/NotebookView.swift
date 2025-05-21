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
                Task {
                    if let (topic, subtopic, note) = noteToDelete {
                        try? await dataManager.deleteNote(note)
                    }
                    noteToDelete = nil
                }
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
                                Text(note.createdAt, style: .date)
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
    @Binding var isPresented: Bool
    @ObservedObject var authManager: AuthManager
    @State private var topics: [Topic] = []
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var notes: [Note] = []
    @State private var isAddingTopic: Bool = false
    @State private var isAddingSubtopic: Bool = false
    @State private var isAddingNote: Bool = false
    @State private var newTopicTitle: String = ""
    @State private var newTopicDescription: String = ""
    @State private var newSubtopicTitle: String = ""
    @State private var newSubtopicDescription: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(topics) { topic in
                    TopicSection(
                        topic: topic,
                        selectedTopic: $selectedTopic,
                        selectedSubtopic: $selectedSubtopic,
                        notes: $notes,
                        isAddingSubtopic: $isAddingSubtopic,
                        newSubtopicTitle: $newSubtopicTitle,
                        newSubtopicDescription: $newSubtopicDescription
                    )
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Notebook")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isAddingTopic = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .sheet(isPresented: $isAddingTopic) {
                AddTopicView(
                    isPresented: $isAddingTopic,
                    title: $newTopicTitle,
                    description: $newTopicDescription,
                    onSave: addTopic
                )
            }
        }
    }
    
    private func addTopic() {
        Task {
            let newTopic = Topic(
                title: newTopicTitle,
                description: newTopicDescription
            )
            topics.append(newTopic)
            newTopicTitle = ""
            newTopicDescription = ""
        }
    }
}

struct TopicSection: View {
    let topic: Topic
    @Binding var selectedTopic: Topic?
    @Binding var selectedSubtopic: Subtopic?
    @Binding var notes: [Note]
    @Binding var isAddingSubtopic: Bool
    @Binding var newSubtopicTitle: String
    @Binding var newSubtopicDescription: String
    
    var body: some View {
        Section(header: Text(topic.title)) {
            ForEach(notes.filter { $0.topicId == topic.id }) { note in
                NavigationLink(destination: NoteView(note: note, isPresented: .constant(true))) {
                    VStack(alignment: .leading) {
                        Text(note.title)
                            .font(.headline)
                        Text(note.content)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
            }
            
            Button(action: {
                selectedTopic = topic
                isAddingSubtopic = true
            }) {
                Label("Add Subtopic", systemImage: "plus")
            }
        }
    }
}

struct AddTopicView: View {
    @Binding var isPresented: Bool
    @Binding var title: String
    @Binding var description: String
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Topic Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("New Topic")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    onSave()
                    isPresented = false
                }
                .disabled(title.isEmpty)
            )
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
    @State private var isShowingNewSubtopicSheet = false
    @State private var isShowingNewNoteSheet = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @ObservedObject var dataManager: DataManager
    @State private var subtopicToEdit: (Topic, Subtopic)?
    @State private var editedSubtopicTitle: String = ""
    @State private var isShowingEditSubtopicSheet = false
    @State private var subtopicToDelete: (Topic, Subtopic)?
    
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
                        }
                    }
                    .contextMenu {
                        Button {
                            subtopicToEdit = (topic, subtopic)
                            editedSubtopicTitle = subtopic.title
                            isShowingEditSubtopicSheet = true
                        } label: {
                            Label("Edit Title", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            subtopicToDelete = (topic, subtopic)
                        } label: {
                            Label("Delete Subtopic", systemImage: "trash")
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
        .sheet(isPresented: $isShowingEditSubtopicSheet) {
            NavigationView {
                Form {
                    TextField("Subtopic Title", text: $editedSubtopicTitle)
                }
                .navigationTitle("Edit Subtopic Title")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        isShowingEditSubtopicSheet = false
                    },
                    trailing: Button("Save") {
                        if let (topic, subtopic) = subtopicToEdit {
                            Task {
                                var updatedSubtopic = subtopic
                                updatedSubtopic.title = editedSubtopicTitle
                                try? await dataManager.updateSubtopic(updatedSubtopic)
                            }
                        }
                        isShowingEditSubtopicSheet = false
                    }
                    .disabled(editedSubtopicTitle.isEmpty)
                )
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
                    Task {
                        try? await dataManager.deleteSubtopic(subtopic)
                    }
                }
                subtopicToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this subtopic? This will also delete all its notes.")
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
                Text(note.createdAt, style: .date)
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
                
                Text(note.createdAt, style: .date)
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
                    Task {
                        let newTopic = Topic(title: title, description: "")
                        try? await dataManager.createTopic(newTopic)
                        dismiss()
                    }
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
                    Task {
                        let newSubtopic = Subtopic(title: title, description: "", topicId: topic.id)
                        try? await dataManager.createSubtopic(newSubtopic)
                        dismiss()
                    }
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
                    dataManager.addNoteToSubtopic(to: subtopic, in: topic, title: title, content: content)
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

struct NotebookView_Previews: PreviewProvider {
    static var previews: some View {
        NotebookView(isPresented: .constant(true), authManager: AuthManager())
    }
}
