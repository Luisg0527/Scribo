import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import Vision

// MARK: - Classification Response
struct TextClassificationResponse: Codable {
    let topic: String
    let subtopic: String
    let note_name: String
    let raw_scores: [String: Double]
}

// MARK: - Chat Model
struct Chat: Identifiable, Codable {
    let id: UUID
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var userId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case messages = "chat_messages"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case title
        case userId = "user_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        title = try container.decode(String.self, forKey: .title)
        
        // Decode dates from ISO8601 strings
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        guard let createdAt = dateFormatter.date(from: createdAtString),
              let updatedAt = dateFormatter.date(from: updatedAtString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Date string does not match format")
        }
        
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        // Decode user_id as UUID
        if let userIdString = try container.decodeIfPresent(String.self, forKey: .userId) {
            userId = UUID(uuidString: userIdString)
        } else {
            userId = nil
        }
    }
    
    init(id: UUID = UUID(), messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date(), title: String = "New Chat", userId: UUID? = nil) {
        self.id = id
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.userId = userId
    }
}

struct DocumentMessage: Identifiable, Codable {
    let id = UUID()
    let url: URL
    let name: String
    let type: String
}

// MARK: - Chat View
struct ChatView: View {
    @Binding var chats: [Chat]
    @Binding var currentChat: Chat?
    @State private var promptText: String = ""
    @State private var isTextFieldFocused: Bool = false
    @State private var isAttachmentMenuShowing: Bool = false
    @State private var showActionCards: Bool = true
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedDocument: URL?
    @State private var isDocumentPickerPresented = false
    @State private var isProcessingOCR: Bool = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var currentImageURL: String?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var chatManager = ChatManager()
    @StateObject private var dataManager = DataManager()
    @StateObject private var alertManager = AlertManager()
    @State private var classificationService = TextClassificationService(
        //serverURL: ProcessInfo.processInfo.environment["CLASSIFICATION_SERVER_URL"] ?? "Placeholder",
        //apiKey: ProcessInfo.processInfo.environment["CLASSIFICATION_API_KEY"] ?? "Placeholder"
        serverURL: "http://10.22.149.108:8000/classify",
        apiKey: "dev-secret-12345"
    )
    @State private var showPhotoLibraryPermissionAlert = false
    @State private var photoLibraryPermissionDenied = false
    @State private var isShowing = false
    @FocusState private var isFocused: Bool
    @State private var animatedText = ""
    @State private var hasAnimatedText = false
    
    let welcomeMessage = "Hello! What can I help you with?"
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                chatMessagesView
                chatInputView
                attachmentMenuView
            }
            
            if showActionCards {
                actionCardsView
                    .offset(y: isAttachmentMenuShowing ? -270 : -80)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isAttachmentMenuShowing)
        .onTapGesture {
            isFocused = false
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onChange(of: isDarkMode) { oldValue, newValue in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = newValue ? .dark : .light
                }
            }
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            withAnimation {
                showActionCards = newValue.isEmpty
            }
            
            Task {
                for photo in newValue {
                    do {
                        if let data = try await photo.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    if !selectedImages.contains(where: { $0.pngData() == uiImage.pngData() }) {
                                        selectedImages.append(uiImage)
                                    }
                                }
                            } else {
                                print("❌ Failed to create UIImage from data")
                            }
                        } else {
                            print("❌ Failed to load photo data")
                        }
                    } catch {
                        print("❌ Error loading photo: \(error.localizedDescription)")
                    }
                }
            }
        }
        .alert("Photo Library Access Required", isPresented: $showPhotoLibraryPermissionAlert) {
            Button("Cancel", role: .cancel) {
                photoLibraryPermissionDenied = false
            }
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Please allow access to your photo library in Settings to save photos.")
        }
    }
    
    private func saveChats() {
        if let encoded = try? JSONEncoder().encode(chats) {
            UserDefaults.standard.set(encoded, forKey: "savedChats")
        }
    }
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    if let currentChat = currentChat, currentChat.messages.isEmpty {
                        welcomeView
                    } else {
                        messagesList
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await reloadChat()
            }
            .onChange(of: currentChat?.messages) { _, _ in
                withAnimation {
                    proxy.scrollTo(currentChat?.messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("ThreeDots")
                .frame(width: 97, height: 97)
                .foregroundColor(.appAccent1)
            
            Text(hasAnimatedText ? welcomeMessage : animatedText)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.appText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .onAppear {
                    if !hasAnimatedText {
                        animateText()
                    }
                }
            
            Spacer()
        }
        .padding([.top, .leading, .trailing], 30)
        .frame(maxHeight: .infinity)
    }
    
    private var actionCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach([
                    "Categorize my notes",
                    "Create a new topic",
                    "Find related content",
                    "Summarize this text",
                    "Generate flashcards",
                    "Explain this concept"
                ], id: \.self) { action in
                    actionCardButton(action)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(height: 70)
        .background(Color.clear)
        .padding(.bottom, 20)
    }
    
    private func actionCardButton(_ action: String) -> some View {
        Button(action: {
            promptText = action
            isFocused = true
            showActionCards = false
        }) {
            Text(action)
                .font(.body)
                .fontWeight(.regular)
                .foregroundColor(.appTextSecondary)
                .multilineTextAlignment(.leading)
                .frame(width: 200)
                .frame(height: 50)
                .background(Color.appAccent2)
                .cornerRadius(13)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    private var messagesList: some View {
        ForEach(currentChat?.messages ?? []) { message in
            ChatMessageView(message: message)
                .id(message.id)
        }
    }
    
    private var chatInputView: some View {
        VStack(spacing: 0) {
            if let selectedPhotos = selectedPhotos.first {
                photoPreviewView(selectedPhotos)
            }
            
            if let selectedDocument = selectedDocument {
                documentPreviewView(selectedDocument)
            }
            
            inputBarView
        }
    }
    
    private func photoPreviewView(_ photo: PhotosPickerItem) -> some View {
        HStack {
            PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                ZStack {
                    if let firstImage = selectedImages.first {
                        Image(uiImage: firstImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appAccent1, lineWidth: 2)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appCardBackground)
                            .frame(width: 60, height: 60)
                            .overlay(
                                ProgressView()
                                    .frame(width: 30, height: 30)
                            )
                    }
                    
                    if selectedImages.count > 1 {
                        Text("+\(selectedImages.count - 1)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .offset(x: 20, y: 20)
                    }
                }
            }
            
            Button(action: {
                selectedPhotos = []
                selectedImages = []
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private func documentPreviewView(_ document: URL) -> some View {
        HStack {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.appAccent1)
                Text(document.lastPathComponent)
                    .foregroundColor(.appAccent1)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appCardBackground)
            .cornerRadius(16)
            
            Button(action: {
                self.selectedDocument = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var inputBarView: some View {
        HStack(spacing: 12) {
            attachmentButton
            textInputField
            sendButton
        }
        .padding([.horizontal, .bottom], 20)
        .padding(.top, 8)
        .background(Color.appHeaderBackground)
    }
    
    private var attachmentButton: some View {
        Button(action: {
            withAnimation {
                isAttachmentMenuShowing.toggle()
            }
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.appAccent1)
        }
    }
    
    private var textInputField: some View {
        TextField("Message", text: $promptText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appCardBackground)
            .cornerRadius(20)
            .frame(maxWidth: .infinity)
            .foregroundColor(.appText)
            .accentColor(.appAccent1)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .focused($isFocused)
            .onChange(of: isFocused) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isTextFieldFocused = newValue
                    if newValue {
                        isAttachmentMenuShowing = false
                    }
                }
            }
            .submitLabel(.send)
            .onSubmit {
                Task {
                    await sendMessage()
                }
            }
    }
    
    private var sendButton: some View {
        Button {
            Task {
                await sendMessage()
            }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.appAccent1)
                .opacity(promptText.isEmpty && selectedPhotos.isEmpty && selectedDocument == nil ? 0.5 : 1)
        }
        .disabled(promptText.isEmpty && selectedPhotos.isEmpty && selectedDocument == nil)
    }
    
    private var attachmentMenuView: some View {
        Group {
            if isAttachmentMenuShowing {
                AttachmentMenuView(isShowing: $isAttachmentMenuShowing, selectedPhotos: $selectedPhotos, selectedDocument: $selectedDocument, isDocumentPickerPresented: $isDocumentPickerPresented)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func processImageWithOCR(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { 
            print("Failed to get CGImage from UIImage")
            return "No text could be extracted from this image. Please describe the image content."
        }
        
        // Save the image and get its URL
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            do {
                try data.write(to: fileURL)
                await MainActor.run {
                    currentImageURL = fileName
                }
            } catch {
                print("Error saving image: \(error)")
            }
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
            guard let observations = request.results else { 
                print("No text observations found in image")
                return "No text could be extracted from this image. Please describe the image content."
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            print("OCR extracted text: \(recognizedText)")
            
            if recognizedText.isEmpty {
                print("OCR returned empty text")
                return "No text could be extracted from this image. Please describe the image content."
            }
            
            return recognizedText
        } catch {
            print("OCR Error: \(error.localizedDescription)")
            return "No text could be extracted from this image. Please describe the image content."
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return granted == .authorized || granted == .limited
        case .denied, .restricted:
            await MainActor.run {
                photoLibraryPermissionDenied = true
                showPhotoLibraryPermissionAlert = true
            }
            return false
        @unknown default:
            return false
        }
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        guard await requestPhotoLibraryPermission() else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"])
        }
        
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: image.jpegData(compressionQuality: 0.8)!, options: nil)
        }
    }
    
    private func sendMessage() async {
        guard !promptText.isEmpty || !selectedPhotos.isEmpty || selectedDocument != nil else { return }
        guard var currentChat = currentChat else { return }
        
        // Add user message
        let userMessage = ChatMessage(
            content: promptText,
            image: nil,
            document: selectedDocument.map { url in
                DocumentMessage(
                    url: url,
                    name: url.lastPathComponent,
                    type: url.pathExtension
                )
            },
            isUser: true,
            timestamp: Date(),
            chatId: currentChat.id
        )
        
        // Add processing message
        let processingMessage = ChatMessage(
            content: "Processing...",
            image: nil,
            document: nil,
            isUser: false,
            timestamp: Date(),
            isProcessing: true,
            chatId: currentChat.id
        )
        
        await MainActor.run {
            currentChat.messages.append(userMessage)
            currentChat.messages.append(processingMessage)
            if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                chats[index] = currentChat
            }
            self.currentChat = currentChat
        }
        
        // Save message to database
        do {
            try await chatManager.addMessage(userMessage, to: currentChat.id)
            try await chatManager.updateChat(currentChat)
        } catch {
            print("❌ Failed to save message: \(error.localizedDescription)")
        }
        
        // Clear input
        let currentPhotos = selectedPhotos
        let currentDocument = selectedDocument
        await MainActor.run {
            promptText = ""
            selectedPhotos = []
            selectedImages = []
            selectedDocument = nil
        }
        
        // Process the photos if any were selected
        if !currentPhotos.isEmpty {
            do {
                for photo in currentPhotos {
                    do {
                        if let data = try await photo.loadTransferable(type: Data.self) {
                            // Save image to photo library and get reference
                            let fileName = "\(UUID().uuidString).jpg"
                            let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
                            try data.write(to: fileURL)
                            
                            if let uiImage = UIImage(data: data) {
                                if let text = await processImageWithOCR(uiImage) {
                                    // Classify the text
                                    do {
                                        let classification = try await classificationService.classifyText(text)
                                        
                                        // Add the photo message with OCR results and classification
                                        let photoMessage = ChatMessage(
                                            content: "I've created a note titled \"\(classification.note_name)\" under \(classification.topic) > \(classification.subtopic). Redirecting you to the note...",
                                            image: uiImage,
                                            document: nil,
                                            isUser: false,
                                            timestamp: Date(),
                                            chatId: currentChat.id
                                        )
                                        
                                        await MainActor.run {
                                            // Remove processing message
                                            if let index = currentChat.messages.lastIndex(where: { $0.isProcessing }) {
                                                currentChat.messages.remove(at: index)
                                            }
                                            currentChat.messages.append(photoMessage)
                                            // Update chat title with the classified note name
                                            if currentChat.title == "Welcome" || currentChat.title == "Processing..." {
                                                currentChat.title = classification.note_name
                                                if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                                                    chats[index] = currentChat
                                                }
                                            }
                                            self.currentChat = currentChat
                                        }
                                        
                                        // Save message to database
                                        try await chatManager.addMessage(photoMessage, to: currentChat.id)
                                        
                                        // Create the note
                                        try await createNoteFromClassification(classification)
                                    } catch {
                                        print("❌ ChatView: Classification error: \(error.localizedDescription)")
                                        let photoMessage = ChatMessage(
                                            content: "I've extracted text from your image but couldn't automatically categorize it. You can manually organize it later.",
                                            image: uiImage,
                                            document: nil,
                                            isUser: false,
                                            timestamp: Date(),
                                            chatId: currentChat.id
                                        )
                                        
                                        await MainActor.run {
                                            // Remove processing message
                                            if let index = currentChat.messages.lastIndex(where: { $0.isProcessing }) {
                                                currentChat.messages.remove(at: index)
                                            }
                                            currentChat.messages.append(photoMessage)
                                            if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                                                chats[index] = currentChat
                                            }
                                            self.currentChat = currentChat
                                        }
                                        
                                        // Save message to database
                                        try await chatManager.addMessage(photoMessage, to: currentChat.id)
                                        
                                        // Create a default note even if classification fails
                                        let defaultClassification = TextClassificationResponse(
                                            topic: "Uncategorized",
                                            subtopic: "General",
                                            note_name: "Uncategorized Note",
                                            raw_scores: [:]
                                        )
                                        try? await createNoteFromClassification(defaultClassification)
                                    }
                                } else {
                                    print("❌ ChatView: OCR failed to extract text")
                                    let photoMessage = ChatMessage(
                                        content: "I couldn't extract any text from this image. Please try uploading a clearer image or describe what you'd like to do.",
                                        image: uiImage,
                                        document: nil,
                                        isUser: false,
                                        timestamp: Date(),
                                        chatId: currentChat.id
                                    )
                                    
                                    await MainActor.run {
                                        // Remove processing message
                                        if let index = currentChat.messages.lastIndex(where: { $0.isProcessing }) {
                                            currentChat.messages.remove(at: index)
                                        }
                                        currentChat.messages.append(photoMessage)
                                        if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                                            chats[index] = currentChat
                                        }
                                        self.currentChat = currentChat
                                    }
                                    
                                    // Save message to database
                                    try await chatManager.addMessage(photoMessage, to: currentChat.id)
                                }
                            }
                        }
                    } catch {
                        print("❌ ChatView: Failed to process photo: \(error.localizedDescription)")
                        let errorMessage = ChatMessage(
                            content: "Failed to process the image. Please try again with a different image.",
                            image: nil,
                            document: nil,
                            isUser: false,
                            timestamp: Date(),
                            chatId: currentChat.id
                        )
                        
                        await MainActor.run {
                            // Remove processing message
                            if let index = currentChat.messages.lastIndex(where: { $0.isProcessing }) {
                                currentChat.messages.remove(at: index)
                            }
                            currentChat.messages.append(errorMessage)
                            if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                                chats[index] = currentChat
                            }
                            self.currentChat = currentChat
                        }
                        
                        // Save error message to database
                        try? await chatManager.addMessage(errorMessage, to: currentChat.id)
                    }
                }
            } catch {
                print("❌ ChatView: Failed to process photos: \(error.localizedDescription)")
            }
        } else if let document = currentDocument {
            // Handle document
            let documentMessage = ChatMessage(
                content: "I've received your document: \(document.lastPathComponent). I'll help you organize it.",
                image: nil,
                document: DocumentMessage(url: document, name: document.lastPathComponent, type: document.pathExtension),
                isUser: false,
                timestamp: Date(),
                chatId: currentChat.id
            )
            
            await MainActor.run {
                currentChat.messages.removeLast() // Remove processing message
                currentChat.messages.append(documentMessage)
                if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                    chats[index] = currentChat
                }
                self.currentChat = currentChat
            }
            
            // Save message to database
            do {
                try await chatManager.addMessage(documentMessage, to: currentChat.id)
            } catch {
                print("❌ Failed to save document message: \(error.localizedDescription)")
            }
        } else {
            // Handle text-only messages
            let aiResponse = ChatMessage(
                content: "To help you organize your content, you can:\n\n1. Upload an image or document to automatically categorize it\n2. Use the action cards below to perform specific tasks\n3. Type your request and I'll guide you through the process",
                image: nil,
                document: nil,
                isUser: false,
                timestamp: Date(),
                chatId: currentChat.id
            )
            
            await MainActor.run {
                currentChat.messages.removeLast() // Remove processing message
                currentChat.messages.append(aiResponse)
                if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                    chats[index] = currentChat
                }
                self.currentChat = currentChat
            }
            
            // Save message to database
            do {
                try await chatManager.addMessage(aiResponse, to: currentChat.id)
            } catch {
                print("❌ Failed to save AI response: \(error.localizedDescription)")
            }
        }
    }
    
    private func createNoteFromClassification(_ classification: TextClassificationResponse) async throws {
        // Find or create topic
        var topic = dataManager.topics.first { $0.title == classification.topic }
        if topic == nil {
            topic = try await dataManager.addTopic(title: classification.topic)
        }
        guard let topic = topic else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find topic"]) }
        
        // Find or create subtopic
        var subtopic = topic.subtopics.first { $0.title == classification.subtopic }
        if subtopic == nil {
            subtopic = try await dataManager.addSubtopic(to: topic, title: classification.subtopic)
        }
        guard let subtopic = subtopic else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find subtopic"]) }
        
        // Create note with the OCR text from the message
        let note = try await dataManager.addNote(
            to: subtopic,
            in: topic,
            title: classification.note_name,
            content: currentChat?.messages.last?.content ?? "",  // Use the OCR text from the last message
            attachmentUrls: currentImageURL != nil ? [currentImageURL!] : nil
        )
        
        // Update UI on main thread
        await MainActor.run {
            noteDisplayState.currentTopic = topic
            noteDisplayState.currentSubtopic = subtopic
            noteDisplayState.currentNote = note
            noteDisplayState.isShowingNote = true
            isShowing = false
        }
    }
    
    private func animateText() {
        let fullText = welcomeMessage
        var currentIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if currentIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
                animatedText += String(fullText[index])
                currentIndex += 1
            } else {
                timer.invalidate()
                hasAnimatedText = true
            }
        }
    }
    
    private func reloadChat() async {
        guard let currentChat = currentChat else { return }
        do {
            let updatedChat = try await chatManager.getChat(currentChat.id)
            await MainActor.run {
                if let index = chats.firstIndex(where: { $0.id == currentChat.id }) {
                    chats[index] = updatedChat
                }
                self.currentChat = updatedChat
            }
        } catch {
            print("❌ Failed to reload chat: \(error.localizedDescription)")
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to reload chat: \(error.localizedDescription)"))
            }
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if let image = message.image {
                    ScrollableImageView(
                        image: Image(uiImage: image),
                        containerHeight: 200
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                
                if let document = message.document {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.appAccent1)
                        Text(document.name)
                            .foregroundColor(.appAccent1)
                    }
                    .padding(12)
                    .background(Color.appCardBackground)
                    .cornerRadius(16)
                }
                
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.appAccent1 : Color.appCardBackground)
                        .foregroundColor(message.isUser ? .appAccent2 : .appText)
                        .cornerRadius(16)
                }
                
                if message.isProcessing {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
                
                if let error = message.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.appTextSecondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .opacity(message.isProcessing ? 0.8 : 1.0)
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(chats: .constant([Chat(title: "Welcome")]), currentChat: .constant(nil))
    }
}

// MARK: - Chat List View
struct ChatListView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var chats: [Chat]
    @Binding var currentChat: Chat
    @StateObject private var chatManager = ChatManager()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(chats.sorted(by: { $0.updatedAt > $1.updatedAt })) { chat in
                    Button(action: {
                        currentChat = chat
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.appAccent1)
                            VStack(alignment: .leading) {
                                Text(chat.title)
                                    .foregroundColor(.appText)
                                if !chat.messages.isEmpty {
                                    Text(chat.messages.last?.content ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .onDelete { indexSet in
                    let chatsToDelete = indexSet.map { chats.sorted(by: { $0.updatedAt > $1.updatedAt })[$0] }
                    Task {
                        do {
                            // Delete chats from database
                            for chat in chatsToDelete {
                                try await chatManager.deleteChat(chat.id)
                            }
                            
                            await MainActor.run {
                                // Remove from local array
                                chats.removeAll { chat in
                                    chatsToDelete.contains { $0.id == chat.id }
                                }
                                
                                // If no chats left, create a new welcome chat
                                if chats.isEmpty {
                                    Task {
                                        do {
                                            let welcomeChat = try await chatManager.createChat(title: "Welcome")
                                            await MainActor.run {
                                                chats.append(welcomeChat)
                                                currentChat = welcomeChat
                                            }
                                        } catch {
                                            print("❌ Failed to create welcome chat: \(error.localizedDescription)")
                                        }
                                    }
                                } else if chatsToDelete.contains(where: { $0.id == currentChat.id }) {
                                    currentChat = chats[0]
                                }
                            }
                        } catch {
                            print("❌ Failed to delete chats: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            do {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "MMM d, h:mm a"
                                let timestamp = dateFormatter.string(from: Date())
                                let newChat = try await chatManager.createChat(title: "Chat \(timestamp)")
                                await MainActor.run {
                                    chats.append(newChat)
                                    currentChat = newChat
                                    dismiss()
                                }
                            } catch {
                                print("❌ Failed to create new chat: \(error.localizedDescription)")
                            }
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

// MARK: - Attachment Menu View
struct AttachmentMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var selectedDocument: URL?
    @Binding var isDocumentPickerPresented: Bool
    @State private var isShowingCamera = false
    
    let menuItems = [
        ("doc.fill", "Document", "Share a document"),
        ("photo.fill", "Photos", "Share photos"),
        ("camera.fill", "Camera", "Take a photo")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(menuItems, id: \.1) { item in
                    if item.1 == "Photos" {
                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                            menuItemView(item)
                        }
                    } else if item.1 == "Document" {
                        Button(action: {
                            isDocumentPickerPresented = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
                            menuItemView(item)
                        }
                    } else if item.1 == "Camera" {
                        Button(action: {
                            isShowingCamera = true
                        }) {
                            menuItemView(item)
                        }
                    }
                }
            }
            .background(Color.appHeaderBackground)
        }
        .frame(height: 190)
        .background(Color.appHeaderBackground)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView { image in
                if let image = image {
                    // Save to photo library and create PhotosPickerItem
                    PHPhotoLibrary.requestAuthorization { status in
                        if status == .authorized {
                            PHPhotoLibrary.shared().performChanges({
                                let request = PHAssetCreationRequest.forAsset()
                                if let data = image.jpegData(compressionQuality: 0.8) {
                                    request.addResource(with: .photo, data: data, options: nil)
                                }
                            }) { success, error in
                                if success {
                                    print("📸 Camera: Image saved to photo library")
                                    // Fetch the created asset
                                    let fetchOptions = PHFetchOptions()
                                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                                    let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                                    if let asset = fetchResult.firstObject {
                                        DispatchQueue.main.async {
                                            let pickerItem = PhotosPickerItem(itemIdentifier: asset.localIdentifier)
                                            selectedPhotos.append(pickerItem)
                                            print("📸 Camera: PhotosPickerItem created with identifier: \(asset.localIdentifier)")
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isShowing = false
                                            }
                                        }
                                    }
                                } else {
                                    print("❌ Camera: Failed to save to photo library: \(error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                        } else {
                            print("❌ Camera: Photo library access denied")
                        }
                    }
                }
            }
        }
    }
    
    private func menuItemView(_ item: (String, String, String)) -> some View {
        HStack(spacing: 16) {
            Image(systemName: item.0)
                .font(.system(size: 24))
                .foregroundColor(.appAccent1)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.1)
                    .font(.body)
                    .foregroundColor(.appText)
                Text(item.2)
                    .font(.caption)
                    .foregroundColor(.appText.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.appHeaderBackground)
    }
} 
