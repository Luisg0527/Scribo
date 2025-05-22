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
    @ObservedObject var dataManager: DataManager
    
    init(note: Note?, isPresented: Binding<Bool>, dataManager: DataManager) {
        print("NoteView initialized with note: \(String(describing: note?.id))")
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note?.title ?? "")
        self._editedContent = State(initialValue: note?.content ?? "")
        self.isNewNote = note == nil
        self.dataManager = dataManager
        
        // Load existing image if note has an attachment_url
        if let note = note, let attachmentUrl = note.attachment_url {
            if let image = loadImage(from: attachmentUrl) {
                self._noteImage = State(initialValue: image)
            }
        }
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
            .onAppear {
                print("NoteView appeared with note: \(String(describing: noteDisplayState.currentNote?.id))")
                print("Current topic: \(String(describing: noteDisplayState.currentTopic?.id))")
                print("Current subtopic: \(String(describing: noteDisplayState.currentSubtopic?.id))")
                
                // Add to recent notes when view appears
                if let note = noteDisplayState.currentNote {
                    print("Adding note to recent notes: \(note.id)")
                    Task {
                        do {
                            try await dataManager.addRecentNote(noteId: note.id.uuidString)
                            print("Successfully added note to recent notes")
                        } catch {
                            print("Error adding recent note: \(error)")
                        }
                    }
                }
            }
            
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
        guard let topic = noteDisplayState.currentTopic,
              let subtopic = noteDisplayState.currentSubtopic else { return }
        
        // Save image if present
        var attachmentUrl: String? = nil
        if let image = noteImage {
            attachmentUrl = saveImage(image)
        }
        
        if isNewNote {
            // Create new note
            dataManager.addNote(to: subtopic, in: topic, title: editedTitle, content: editedContent, attachmentUrl: attachmentUrl)
        } else if let note = noteDisplayState.currentNote {
            // Update existing note
            print("Updating note: \(note.id)")
            dataManager.updateNote(note, in: subtopic, in: topic, newTitle: editedTitle, newContent: editedContent, newAttachmentUrl: attachmentUrl)
        }
    }
    
    private func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    private func loadImage(from fileName: String) -> UIImage? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
} 