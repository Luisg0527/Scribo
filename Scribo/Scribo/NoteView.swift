import SwiftUI
import PhotosUI

struct NoteView: View {
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @Binding var isPresented: Bool
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var noteImage: UIImage?
    let isNewNote: Bool
    
    init(note: Note?, isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note?.title ?? "")
        self._editedContent = State(initialValue: note?.content ?? "")
        self.isNewNote = note == nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    if let topic = noteDisplayState.currentTopic {
                        Text(topic.title)
                            .font(.subheadline)
                            .foregroundColor(.appAccent)
                    }
                    if let subtopic = noteDisplayState.currentSubtopic {
                        Text(subtopic.title)
                            .font(.headline)
                            .foregroundColor(.appText)
                    }
                }
                
                Spacer()
                
                // Save button
                Button(action: {
                    saveNote()
                    isPresented = false
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.appAccent)
                }
            }
            .padding()
            .background(Color.appHeaderBackground)
            
            // Note Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title Field
                    TextField("Title", text: $editedTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appText)
                        .padding()
                        .background(Color.appCardBackground)
                        .cornerRadius(12)
                    
                    // Image Section
                    if let noteImage = noteImage {
                        Image(uiImage: noteImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                            .overlay(
                                Button(action: {
                                    self.noteImage = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                                .padding(8),
                                alignment: .topTrailing
                            )
                    }
                    
                    // Add Image Button
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                            Text(noteImage == nil ? "Add Image" : "Change Image")
                                .font(.headline)
                        }
                        .foregroundColor(.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appCardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Content Field
                    TextEditor(text: $editedContent)
                        .font(.body)
                        .foregroundColor(.appText)
                        .frame(minHeight: 200)
                        .padding()
                        .background(Color.appCardBackground)
                        .cornerRadius(12)
                }
                .padding()
            }
            .background(Color.appBackground)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { oldValue, newValue in
            if let newValue {
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        noteImage = uiImage
                    }
                }
            }
        }
    }
    
    private func saveNote() {
        // TODO: Implement save functionality
        // This should save the note to your data store
        // For now, we'll just update the display state
        if isNewNote {
            let newNote = Note(
                title: editedTitle,
                content: editedContent,
                photoURL: nil, // TODO: Save image and get URL
                date: Date()
            )
            noteDisplayState.currentNote = newNote
        } else {
            // Update existing note
            var updatedNote = noteDisplayState.currentNote
            updatedNote?.title = editedTitle
            updatedNote?.content = editedContent
            // TODO: Update image URL if changed
            noteDisplayState.currentNote = updatedNote
        }
    }
} 