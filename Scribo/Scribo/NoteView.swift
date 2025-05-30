import SwiftUI
import PhotosUI
import AVFoundation

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
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var noteImages: [UIImage] = []
    let isNewNote: Bool
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss
    @State private var showingImagePicker = false
    @State private var selectedImageIndex: Int?
    @State private var showingDeleteConfirmation = false
    @State private var showingCamera = false
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) var colorScheme
    
    enum Field {
        case title, content
    }
    
    init(note: Note?, isPresented: Binding<Bool>, dataManager: DataManager) {
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note?.title ?? "")
        self._editedContent = State(initialValue: note?.content ?? "")
        self.isNewNote = note == nil
        self.dataManager = dataManager
        
        if let note = note, let attachmentUrls = note.attachment_urls {
            let images = attachmentUrls.compactMap { url in
                loadImage(from: url)
            }
            self._noteImages = State(initialValue: images)
        }
    }
    
    private func loadImage(from url: String) -> UIImage? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(url)
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveImage(_ image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            do {
                try data.write(to: fileURL)
                return fileName
            } catch {
                print("Error saving image: \(error)")
                return nil
            }
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with topic/subtopic
                if let topic = noteDisplayState.currentTopic {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(topic.title)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let subtopic = noteDisplayState.currentSubtopic {
                                Text(subtopic.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                
                // Title and Content
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $editedTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($focusedField, equals: .title)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Content Section
                    ZStack(alignment: .topLeading) {
                        if editedContent.isEmpty {
                            Text("Start writing your note...")
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                                .padding(.horizontal, 20)
                        }
                        
                        TextEditor(text: $editedContent)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 100)
                            .focused($focusedField, equals: .content)
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 12)
                }

                Divider()
                    .padding(.horizontal, 16)
                    
                
                // Images Section
                if !noteImages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(noteImages.enumerated()), id: \.offset) { index, image in
                                    ImageCard(image: image, index: index, onDelete: {
                                        selectedImageIndex = index
                                        showingDeleteConfirmation = true
                                    }, onTap: {
                                        selectedImageIndex = index
                                        showingImagePicker = true
                                    })
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Add Photos and Camera Buttons
                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(noteImages.isEmpty ? "Add Photos" : "Add More Photos")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    
                    Button(action: {
                        showingCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Take Photo")
                        }
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 32)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await saveNote()
                    }
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                for photo in newValue {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            noteImages.append(uiImage)
                        }
                    }
                }
                selectedPhotos = []
            }
        }
        .alert("Delete Image", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let index = selectedImageIndex {
                    noteImages.remove(at: index)
                }
            }
        } message: {
            Text("Are you sure you want to delete this image?")
        }
        .fullScreenCover(isPresented: $showingImagePicker) {
            if let index = selectedImageIndex {
                ImageDetailView(images: noteImages, initialIndex: index, isPresented: $showingImagePicker)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                if let image = image {
                    noteImages.append(image)
                }
            }
        }
    }
    
    private func saveNote() async {
        do {
            guard let topic = noteDisplayState.currentTopic,
                  let subtopic = noteDisplayState.currentSubtopic else {
                print("❌ Error: Missing topic or subtopic")
                return
            }
            
            var attachmentUrls: [String] = []
            for image in noteImages {
                if let url = saveImage(image) {
                    attachmentUrls.append(url)
                }
            }            
            if isNewNote {
                let newNote = try await dataManager.addNote(
                    to: subtopic,
                    in: topic,
                    title: editedTitle,
                    content: editedContent,
                    attachmentUrls: attachmentUrls
                )
            } else if let note = noteDisplayState.currentNote {
                let updatedNote = try await dataManager.updateNote(
                    note,
                    in: subtopic,
                    in: topic,
                    newTitle: editedTitle,
                    newContent: editedContent,
                    newAttachmentUrls: attachmentUrls
                )
            }
            
            await MainActor.run {
                dismiss()
            }
        } catch {
            print("❌ Error saving note:")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Full error: \(error)")
        }
    }
}

struct ImageCard: View {
    let image: UIImage
    let index: Int
    let onDelete: () -> Void
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .systemGray6 : .systemGray6)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 180, height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                .onTapGesture(perform: onTap)
        }
        .frame(width: 180, height: 180)
        .overlay(
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .shadow(radius: 1)
            }
            .padding(8),
            alignment: .topTrailing
        )
    }
}

struct ImageDetailView: View {
    let images: [UIImage]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    
    init(images: [UIImage], initialIndex: Int, isPresented: Binding<Bool>) {
        self.images = images
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Main image view
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onAppear {
                    // Set the initial page to the selected image
                    currentIndex = initialIndex
                }
                
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding()
                    }
                    Spacer()
                }
                
                // Image counter
                VStack {
                    Spacer()
                    Text("\(currentIndex + 1) of \(images.count)")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.bottom)
                }
            }
        }
    }
}

