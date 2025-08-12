import SwiftUI
import PhotosUI
import UIKit

struct ClearBackgroundTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear  // Make UITextView background clear here
        textView.isScrollEnabled = true
        textView.font = font ?? UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = UIColor.label
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = font ?? UIFont.preferredFont(forTextStyle: .body)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: ClearBackgroundTextEditor
        init(parent: ClearBackgroundTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

struct NoteView: View {
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var isFromChatView: Bool = false

    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var noteImages: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var selectedImageIndex = 0
    @State private var showingDeleteConfirmation = false
    @State private var showingCamera = false
    @State private var showingSaveAlert = false
    @State private var hasChanges: Bool = false
    @State private var showingFullImage = false
    @State private var isPhotoPickerPresented = false
    @State private var isShowingCamera = false
    @State private var isShowingScanner = false

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let isNewNote: Bool

    init(note: Note?, isPresented: Binding<Bool>, dataManager: DataManager) {
        self._isPresented = isPresented
        self._editedTitle = State(initialValue: note?.title ?? "")
        self._editedContent = State(initialValue: note?.content ?? "")
        self.isNewNote = note == nil
        self.dataManager = dataManager
        self._isFromChatView = State(initialValue: !isPresented.wrappedValue)

        if let note = note, let attachmentUrls = note.attachment_urls {
            let images = attachmentUrls.compactMap { url in
                let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(url)
                return UIImage(contentsOfFile: fileURL.path)
            }
            self._noteImages = State(initialValue: images)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    topicHeaderView
                    imageGalleryView
                    .padding(.top, -16)
                    textInputView
                }
                .padding(.top)
            }
            .background(Color.appBackground)

            // Ad Banner with clear visual separation
            VStack(spacing: 0) {
                Divider()
                BannerAdView(adUnitID: "ca-app-pub-3940256099942544/2934735716") // Test ID
                    .frame(height: 50)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.systemBackground))
                Divider()
            }

            bottomBarView
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
        }
        .alert("Save Changes?", isPresented: $showingSaveAlert) {
            Button("Don't Save", role: .destructive) { 
                if isFromChatView {
                    noteDisplayState.isShowingNote = false
                    noteDisplayState.currentNote = nil
                    noteDisplayState.currentTopic = nil
                    noteDisplayState.currentSubtopic = nil
                } else {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
            Button("Save") { 
                Task { 
                    await saveNote()
                    if isFromChatView {
                        noteDisplayState.isShowingNote = false
                        noteDisplayState.currentNote = nil
                        noteDisplayState.currentTopic = nil
                        noteDisplayState.currentSubtopic = nil
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .photosPicker(isPresented: $isPhotoPickerPresented,
                     selection: $selectedPhotos,
                     maxSelectionCount: 10,
                     matching: .images)
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                for photo in newValue {
                    await handleSelectedPhoto(photo)
                }
                // Clear selection after processing
                selectedPhotos.removeAll()
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView { image in
                if let image = image {
                    handleCameraImage(image)
                }
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            DocumentScannerView { scannedImage in
                handleScannedImage(scannedImage)
            }
        }
        .alert("Delete Image", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                noteImages.remove(at: selectedImageIndex)
            }
        } message: {
            Text("Are you sure you want to delete this image?")
        }
        .fullScreenCover(isPresented: $showingFullImage) {
            FullscreenImageViewer(
                image: noteImages[selectedImageIndex],
                allImages: noteImages,
                currentIndex: selectedImageIndex,
                isPresented: $showingFullImage
            )
        }
    }

    private var topicHeaderView: some View {
        Group {
            if let topic = noteDisplayState.currentTopic {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.appAccent1.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(Text(String(topic.title.prefix(1))).bold().foregroundColor(.appAccent1))

                    VStack(alignment: .leading) {
                        Text(topic.title).font(.subheadline).bold().foregroundColor(.appText)
                        if let subtopic = noteDisplayState.currentSubtopic {
                            Text(subtopic.title).font(.caption).foregroundColor(.appTextSecondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color.appHeaderBackground)
            }
        }
    }
    
    private var imageGalleryView: some View {
        Group {
            if !noteImages.isEmpty {
                TabView(selection: $selectedImageIndex) {
                    ForEach(Array(noteImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300)
                            .clipped()
                            .cornerRadius(16)
                            .padding(.horizontal)
                            .tag(index)
                            .onTapGesture {
                                selectedImageIndex = index
                                showingFullImage = true
                            }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 300)
            }
        }
    }
    
    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !editedTitle.isEmpty {
                TextField("Title", text: $editedTitle)
                    .font(.headline)
                    .foregroundColor(.appText)
                    .onChange(of: editedTitle) { _, _ in hasChanges = true }
            }

            ZStack(alignment: .topLeading) {
                // Placeholder
                if editedContent.isEmpty {
                    Text("Enter your text here...")
                        .foregroundColor(.appTextSecondary)
                        .padding(.top, 16)
                        .padding(.leading, 16)
                        .background(Color.clear)
                }

                // TextEditor
                ClearBackgroundTextEditor(text: $editedContent, font: UIFont.preferredFont(forTextStyle: .body))
                    .frame(minHeight: 100)
                    .background(Color.clear)
                    .cornerRadius(12)
                    .onChange(of: editedContent) { _, _ in
                        hasChanges = true
                    }
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)

            }
        }
        .padding(.horizontal)
        
    }

    private var bottomBarView: some View {
        HStack {
            Menu {
                Button(action: { isPhotoPickerPresented = true }) {
                    Label("Photo", systemImage: "photo.fill")
                }
                
                Button(action: { isShowingCamera = true }) {
                    Label("Camera", systemImage: "camera.fill")
                }

                Button(action: { isShowingScanner = true }) {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appAccent1)
            }
            
            Spacer()
            
            Button(action: {
                // TODO: Implement share functionality
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 24))
                    .foregroundColor(.appAccent1)
            }
        }
        .padding()
        .background(Color.appHeaderBackground.opacity(0.8))
    }
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if hasChanges {
                        showingSaveAlert = true
                    } else {
                        if isFromChatView {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                noteDisplayState.isShowingNote = false
                                noteDisplayState.currentNote = nil
                                noteDisplayState.currentTopic = nil
                                noteDisplayState.currentSubtopic = nil
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.appAccent1)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { 
                        await saveNote()
                        if isFromChatView {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                noteDisplayState.isShowingNote = false
                                noteDisplayState.currentNote = nil
                                noteDisplayState.currentTopic = nil
                                noteDisplayState.currentSubtopic = nil
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismiss()
                            }
                        }
                    }
                } label: {
                    Text("Done").fontWeight(.semibold)
                        .foregroundColor(.appAccent1)
                }
            }
        }
    }

    private func saveNote() async {
        do {
            guard let topic = noteDisplayState.currentTopic,
                  let subtopic = noteDisplayState.currentSubtopic else { return }

            var attachmentUrls: [String] = []
            for image in noteImages {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let fileName = UUID().uuidString + ".jpg"
                    let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                    try data.write(to: fileURL)
                    attachmentUrls.append(fileName)
                }
            }

            if isNewNote {
                let newNote = try await dataManager.addNote(to: subtopic, in: topic, title: editedTitle, content: editedContent, attachmentUrls: attachmentUrls)
                notificationManager.playSound(.success)
                notificationManager.scheduleNotification(
                    title: "New Note Created",
                    body: "Your note '\(editedTitle)' has been created successfully"
                )
            } else if let note = noteDisplayState.currentNote {
                var updatedNote = note
                updatedNote.title = editedTitle
                updatedNote.content = editedContent
                updatedNote.attachment_urls = attachmentUrls
                
                _ = try await dataManager.updateNote(
                    updatedNote,
                    in: subtopic,
                    in: topic,
                    newTitle: editedTitle,
                    newContent: editedContent,
                    newAttachmentUrls: attachmentUrls
                )
                notificationManager.playSound(.save)
                notificationManager.scheduleNotification(
                    title: "Note Saved",
                    body: "Your note '\(editedTitle)' has been saved successfully"
                )
            }

            await MainActor.run { dismiss() }

        } catch {
            print("Error saving note: \(error)")
            notificationManager.playSound(.error)
        }
    }

    private func handleSelectedPhoto(_ photo: PhotosPickerItem) async {
        do {
            if let data = try await photo.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    noteImages.append(image)
                    hasChanges = true
                }
                
                // Create upload record
                if let topic = noteDisplayState.currentTopic,
                   let subtopic = noteDisplayState.currentSubtopic,
                   let note = noteDisplayState.currentNote {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
                    try data.write(to: fileURL)
                    
                    let upload = UploadRequest(
                        title: note.title,
                        type: "photo",
                        image_url: fileName,
                        document_url: nil,
                        category: "\(topic.title) > \(subtopic.title)",
                        topic: topic.title,
                        subtopic: subtopic.title,
                        note_id: note.id
                    )
                    
                    try await dataManager.createUpload(upload)
                }
            }
        } catch {
            print("❌ Failed to load photo: \(error.localizedDescription)")
        }
    }
    
    private func handleCameraImage(_ image: UIImage) {
        Task {
            await MainActor.run {
                noteImages.append(image)
                hasChanges = true
            }
            
            // Create upload record
            if let topic = noteDisplayState.currentTopic,
               let subtopic = noteDisplayState.currentSubtopic,
               let note = noteDisplayState.currentNote {
                do {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        try data.write(to: fileURL)
                        
                        let upload = UploadRequest(
                            title: note.title,
                            type: "camera",
                            image_url: fileName,
                            document_url: nil,
                            category: "\(topic.title) > \(subtopic.title)",
                            topic: topic.title,
                            subtopic: subtopic.title,
                            note_id: note.id
                        )
                        
                        try await dataManager.createUpload(upload)
                    }
                } catch {
                    print("❌ Failed to save camera image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleScannedImage(_ image: UIImage) {
        Task {
            await MainActor.run {
                noteImages.append(image)
                hasChanges = true
            }
            
            // Create upload record
            if let topic = noteDisplayState.currentTopic,
               let subtopic = noteDisplayState.currentSubtopic,
               let note = noteDisplayState.currentNote {
                do {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        try data.write(to: fileURL)
                        
                        let upload = UploadRequest(
                            title: note.title,
                            type: "scanned",
                            image_url: fileName,
                            document_url: nil,
                            category: "\(topic.title) > \(subtopic.title)",
                            topic: topic.title,
                            subtopic: subtopic.title,
                            note_id: note.id
                        )
                        
                        try await dataManager.createUpload(upload)
                    }
                } catch {
                    print("❌ Failed to save scanned image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func processAndCategorizeImage(_ image: UIImage, type: DocumentType) async {
        // Save image first
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
            
            // Add to note's attachments
            if let note = noteDisplayState.currentNote {
                var attachmentUrls = note.attachment_urls ?? []
                attachmentUrls.append(fileName)
                
                // Update note in database
                var updatedNote = note
                updatedNote.attachment_urls = attachmentUrls
                
                try? await dataManager.updateNote(
                    updatedNote,
                    in: noteDisplayState.currentSubtopic!,
                    in: noteDisplayState.currentTopic!,
                    newTitle: note.title,
                    newContent: note.content,
                    newAttachmentUrls: attachmentUrls
                )
                
                // Update local note
                await MainActor.run {
                    noteDisplayState.currentNote = updatedNote
                }
            }
        }
    }
}
