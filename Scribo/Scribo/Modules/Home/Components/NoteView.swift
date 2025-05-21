import SwiftUI
import PhotosUI

struct NoteView: View {
    let note: Note
    @Binding var isPresented: Bool
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var noteImage: UIImage?
    @State private var isEditing: Bool = false
    
    init(note: Note, isPresented: Binding<Bool>) {
        self.note = note
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note.title)
        self._editedContent = State(initialValue: note.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            topBar
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isEditing {
                        TextField("Title", text: $editedTitle)
                            .font(.title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal)
                        
                        TextEditor(text: $editedContent)
                            .font(.body)
                            .frame(minHeight: 200)
                            .padding(.horizontal)
                    } else {
                        Text(note.title)
                            .font(.title)
                            .padding(.horizontal)
                        
                        Text(note.content)
                            .font(.body)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color.appBackground)
    }
    
    private var topBar: some View {
        HStack {
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20))
                    .foregroundColor(.appAccent)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 26)
            
            Spacer()
            
            Button(action: {
                if isEditing {
                    // Save changes
                    // TODO: Implement save functionality
                }
                isEditing.toggle()
            }) {
                Text(isEditing ? "Save" : "Edit")
                    .foregroundColor(.appAccent)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 20)
        }
        .background(Color.appHeaderBackground)
    }
    
    private func saveNote() {
        // TODO: Implement save functionality
        // This should save the note to your data store
        // For now, we'll just update the display state
        if let updatedNote = note.updated(title: editedTitle, content: editedContent) {
            // TODO: Update image URL if changed
            // This should be implemented to update the note in the data store
        }
    }
} 