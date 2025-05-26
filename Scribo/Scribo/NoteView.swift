import SwiftUI
import PhotosUI

struct ScrollViewGestureModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture()
                    .onChanged { _ in
                        // This will prevent the parent ScrollView from scrolling
                        // when dragging the image
                    }
            )
    }
}

extension View {
    func preventParentScroll() -> some View {
        modifier(ScrollViewGestureModifier())
    }
}

struct NoteView: View {
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @Binding var isPresented: Bool
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var noteImage: UIImage?
    let isNewNote: Bool
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    
    init(note: Note?, isPresented: Binding<Bool>, dataManager: DataManager) {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Topic and Subtopic Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let topic = noteDisplayState.currentTopic {
                            Text(topic.title)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                        }
                        if let subtopic = noteDisplayState.currentSubtopic {
                            Text(subtopic.title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 16))
                            .foregroundColor(.appAccent1)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .background(Color(.systemBackground))

                // Title Field
                TextField("Title", text: $editedTitle)
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 24)

                // Image Section
                if let noteImage = noteImage {
                    ScrollableImageView(
                        image: Image(uiImage: noteImage),
                        containerHeight: 300
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    .overlay(
                        Button(action: {
                            self.noteImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding(12),
                        alignment: .topTrailing
                    )
                }

                // Content Field
                ZStack(alignment: .topLeading) {
                    if editedContent.isEmpty {
                        Text("Note")
                            .foregroundColor(.gray)
                            .padding(.top, 12)
                            .padding(.horizontal, 18)
                    }
                    TextEditor(text: $editedContent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.clear))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(minHeight: 200)
                }
                .padding()
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    saveNote()
                    dismiss()
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
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
        Task {
            do {
                guard let topic = noteDisplayState.currentTopic,
                      let subtopic = noteDisplayState.currentSubtopic else { return }
                
                // Save image if present
                var attachmentUrl: String? = nil
                if let image = noteImage {
                    attachmentUrl = saveImage(image)
                }
                
                if isNewNote {
                    // Create new note
                    _ = try await dataManager.addNote(
                        to: subtopic,
                        in: topic,
                        title: editedTitle,
                        content: editedContent,
                        attachmentUrl: attachmentUrl
                    )
                } else if let note = noteDisplayState.currentNote {
                    // Update existing note
                    try await dataManager.updateNote(
                        note,
                        in: subtopic,
                        in: topic,
                        newTitle: editedTitle,
                        newContent: editedContent,
                        newAttachmentUrl: attachmentUrl
                    )
                }
            } catch {
                print("Error saving note: \(error)")
                // You might want to show an error alert here
            }
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
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func loadImage(from fileName: String) -> UIImage? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }
} 

