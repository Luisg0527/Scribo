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

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let content: String
    let image: UIImage?
    let document: DocumentMessage?
    let isUser: Bool
    let timestamp: Date
    var isProcessing: Bool = false
    var error: String? = nil
    var chatId: UUID?
    var imageUrl: String?
    var documentUrl: String?
    var documentName: String?
    var documentType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isUser = "is_user"
        case timestamp = "created_at"
        case isProcessing
        case error
        case chatId = "chat_id"
        case imageUrl = "image_url"
        case documentUrl = "document_url"
        case documentName = "document_name"
        case documentType = "document_type"
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isProcessing == rhs.isProcessing &&
        lhs.error == rhs.error
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        
        // Decode timestamp from ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = try container.decode(String.self, forKey: .timestamp)
        guard let timestamp = dateFormatter.date(from: timestampString) else {
            throw DecodingError.dataCorruptedError(forKey: .timestamp, in: container, debugDescription: "Date string does not match format")
        }
        self.timestamp = timestamp
        
        isProcessing = try container.decodeIfPresent(Bool.self, forKey: .isProcessing) ?? false
        error = try container.decodeIfPresent(String.self, forKey: .error)
        chatId = try container.decodeIfPresent(UUID.self, forKey: .chatId)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        documentUrl = try container.decodeIfPresent(String.self, forKey: .documentUrl)
        documentName = try container.decodeIfPresent(String.self, forKey: .documentName)
        documentType = try container.decodeIfPresent(String.self, forKey: .documentType)
        
        // Load image if URL exists
        if let imageUrl = imageUrl {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(imageUrl)
            if let data = try? Data(contentsOf: fileURL),
               let uiImage = UIImage(data: data) {
                image = uiImage
            } else {
                image = nil
            }
        } else {
            image = nil
        }
        
        // Create document message if URL exists
        if let documentUrl = documentUrl,
           let url = URL(string: documentUrl),
           let documentName = documentName,
           let documentType = documentType {
            document = DocumentMessage(url: url, name: documentName, type: documentType)
        } else {
            document = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        
        // Encode timestamp as ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: timestamp), forKey: .timestamp)
        
        try container.encode(isProcessing, forKey: .isProcessing)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(chatId, forKey: .chatId)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(documentUrl, forKey: .documentUrl)
        try container.encodeIfPresent(documentName, forKey: .documentName)
        try container.encodeIfPresent(documentType, forKey: .documentType)
    }
    
    init(content: String, image: UIImage? = nil, document: DocumentMessage? = nil, isUser: Bool, timestamp: Date, isProcessing: Bool = false, error: String? = nil, chatId: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.image = image
        self.document = document
        self.isUser = isUser
        self.timestamp = timestamp
        self.isProcessing = isProcessing
        self.error = error
        self.chatId = chatId
        self.documentName = document?.name
        self.documentType = document?.type
        
        // Save image if provided
        if let image = image {
            let fileName = "\(id).jpg"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
                self.imageUrl = fileName
            } else {
                self.imageUrl = nil
            }
        } else {
            self.imageUrl = nil
        }
        
        // Set document URL if provided
        self.documentUrl = document?.url.absoluteString
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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedDocument: URL?
    @State private var isDocumentPickerPresented = false
    @State private var selectedImage: UIImage?
    @FocusState private var isFocused: Bool
    @State private var animatedText = ""
    @State private var hasAnimatedText = false
    @StateObject private var dataManager = DataManager()
    @StateObject private var chatManager = ChatManager()
    @State private var isProcessingOCR: Bool = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var currentImageURL: String?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    @State private var classificationService = TextClassificationService(
        //serverURL: ProcessInfo.processInfo.environment["CLASSIFICATION_SERVER_URL"] ?? "Placeholder",
        //apiKey: ProcessInfo.processInfo.environment["CLASSIFICATION_API_KEY"] ?? "Placeholder"
        serverURL: "http://10.22.149.108:8000/classify",
        apiKey: "dev-secret-12345"
    )
    @State private var showPhotoLibraryPermissionAlert = false
    @State private var photoLibraryPermissionDenied = false
    
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
        .onChange(of: selectedPhoto) { oldValue, newValue in
            print("📱 ChatView: selectedPhoto changed")
            withAnimation {
                showActionCards = newValue == nil
            }
            if let newValue {
                print("📱 ChatView: New photo selected, attempting to load")
                Task {
                    do {
                        // Try to load the image data
                        if let data = try await newValue.loadTransferable(type: Data.self) {
                            print("📱 ChatView: Successfully loaded image data")
                            if let uiImage = UIImage(data: data) {
                                print("📱 ChatView: Successfully created UIImage from data")
                                await MainActor.run {
                                    selectedImage = uiImage
                                }
                            } else {
                                print("❌ ChatView: Failed to create UIImage from data")
                            }
                        } else {
                            // If loading as Data fails, try to get the asset identifier
                            if let identifier = newValue.itemIdentifier {
                                print("📱 ChatView: Got asset identifier: \(identifier)")
                                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                                if let asset = fetchResult.firstObject {
                                    print("📱 ChatView: Successfully fetched asset")
                                    
                                    let options = PHImageRequestOptions()
                                    options.deliveryMode = .highQualityFormat
                                    options.isNetworkAccessAllowed = true
                                    options.isSynchronous = true
                                    
                                    PHImageManager.default().requestImage(
                                        for: asset,
                                        targetSize: PHImageManagerMaximumSize,
                                        contentMode: .aspectFit,
                                        options: options
                                    ) { image, info in
                                        if let error = info?[PHImageErrorKey] as? Error {
                                            print("❌ ChatView: Error fetching image: \(error.localizedDescription)")
                                            return
                                        }
                                        
                                        if let image = image {
                                            print("📱 ChatView: Successfully loaded image from asset")
                                            Task { @MainActor in
                                                selectedImage = image
                                            }
                                        } else {
                                            print("❌ ChatView: Failed to fetch image from asset")
                                        }
                                    }
                                } else {
                                    print("❌ ChatView: Failed to fetch asset with identifier: \(identifier)")
                                }
                            } else {
                                print("❌ ChatView: No asset identifier available")
                            }
                        }
                    } catch {
                        print("❌ ChatView: Error loading image: \(error.localizedDescription)")
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
                .background(Color.appCardBackground)
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
            if let selectedPhoto = selectedPhoto {
                photoPreviewView(selectedPhoto)
            }
            
            if let selectedDocument = selectedDocument {
                documentPreviewView(selectedDocument)
            }
            
            inputBarView
        }
    }
    
    private func photoPreviewView(_ photo: PhotosPickerItem) -> some View {
        HStack {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(.appAccent1)
                    Text("Change Photo")
                        .foregroundColor(.appAccent1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appCardBackground)
                .cornerRadius(16)
            }
            
            Button(action: {
                self.selectedPhoto = nil
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
                .opacity(promptText.isEmpty && selectedPhoto == nil && selectedDocument == nil ? 0.5 : 1)
        }
        .disabled(promptText.isEmpty && selectedPhoto == nil && selectedDocument == nil)
    }
    
    private var attachmentMenuView: some View {
        Group {
            if isAttachmentMenuShowing {
                AttachmentMenuView(isShowing: $isAttachmentMenuShowing, selectedPhoto: $selectedPhoto, selectedDocument: $selectedDocument, isDocumentPickerPresented: $isDocumentPickerPresented)
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
        guard !promptText.isEmpty || selectedPhoto != nil || selectedDocument != nil else { return }
        guard var currentChat = currentChat else { return }
        
        print("📱 ChatView: Starting to send message")
        
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
            // Update chat title if it's the first message
            if currentChat.messages.count == 2 {
                currentChat.title = promptText.prefix(30) + (promptText.count > 30 ? "..." : "")
            }
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
        let currentPhoto = selectedPhoto
        let currentDocument = selectedDocument
        await MainActor.run {
            promptText = ""
            selectedPhoto = nil
            selectedDocument = nil
        }
        
        // Process the photo if one was selected
        if let photo = currentPhoto {
            print("📱 ChatView: Processing selected photo")
            do {
                if let data = try await photo.loadTransferable(type: Data.self) {
                    print("📱 ChatView: Successfully loaded photo data")
                    if let uiImage = UIImage(data: data) {
                        print("📱 ChatView: Successfully created UIImage from photo data")
                        
                        // Process image with OCR
                        let recognizedText = await processImageWithOCR(uiImage)
                        
                        if let text = recognizedText {
                            print("📱 ChatView: OCR extracted text: \(text)")
                            // Classify the text
                            do {
                                let classification = try await classificationService.classifyText(text)
                                
                                // Add the photo message with OCR results and classification
                                let photoMessage = ChatMessage(
                                    content: """
                                    I've extracted the text from your image and created a note for you. Redirecting you to the note...
                                    """,
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
                                do {
                                    try await chatManager.addMessage(photoMessage, to: currentChat.id)
                                } catch {
                                    print("❌ Failed to save photo message: \(error.localizedDescription)")
                                }
                                
                                // Create the note
                                try await createNoteFromClassification(classification)
                            } catch {
                                print("❌ ChatView: Classification error: \(error.localizedDescription)")
                                let photoMessage = ChatMessage(
                                    content: """
                                    Extracted text:
                                    \(text)
                                    
                                    Note: The text was extracted but couldn't be automatically categorized. You can manually organize it later.
                                    """,
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
                                do {
                                    try await chatManager.addMessage(photoMessage, to: currentChat.id)
                                } catch {
                                    print("❌ Failed to save photo message: \(error.localizedDescription)")
                                }
                                
                                // Create a default note even if classification fails
                                let defaultClassification = TextClassificationResponse(
                                    topic: "Uncategorized",
                                    subtopic: "General",
                                    note_name: "Note from \(Date())",
                                    raw_scores: [:]
                                )
                                try? await createNoteFromClassification(defaultClassification)
                            }
                        } else {
                            print("❌ ChatView: OCR failed to extract text")
                            let photoMessage = ChatMessage(
                                content: "No text could be extracted from this image. Please describe the image content.",
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
                            do {
                                try await chatManager.addMessage(photoMessage, to: currentChat.id)
                            } catch {
                                print("❌ Failed to save photo message: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        print("❌ ChatView: Failed to create UIImage from photo data")
                        let errorMessage = ChatMessage(
                            content: "Failed to process the image. Please try again.",
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
                        
                        // Save message to database
                        do {
                            try await chatManager.addMessage(errorMessage, to: currentChat.id)
                        } catch {
                            print("❌ Failed to save error message: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("❌ ChatView: Failed to load photo data")
                    let errorMessage = ChatMessage(
                        content: "Failed to load the image. Please try again.",
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
                    
                    // Save message to database
                    do {
                        try await chatManager.addMessage(errorMessage, to: currentChat.id)
                    } catch {
                        print("❌ Failed to save error message: \(error.localizedDescription)")
                    }
                }
            } catch {
                print("❌ ChatView: Error processing photo: \(error.localizedDescription)")
                let errorMessage = ChatMessage(
                    content: "Error processing the image: \(error.localizedDescription)",
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
                
                // Save message to database
                do {
                    try await chatManager.addMessage(errorMessage, to: currentChat.id)
                } catch {
                    print("❌ Failed to save error message: \(error.localizedDescription)")
                }
            }
        } else if let document = currentDocument {
            // Handle document
            let documentMessage = ChatMessage(
                content: "I've received your document: \(document.lastPathComponent)",
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
            // Simulate AI response for text-only messages
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            let aiResponse = ChatMessage(
                content: "I understand you want to \(userMessage.content). I'll help you organize this content into appropriate topics and notes.",
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
            attachmentUrl: currentImageURL
        )
        
        // Update UI on main thread
        await MainActor.run {
            // Add success message
            let successMessage = ChatMessage(
                content: "✅ Note created successfully!",
                image: nil,
                document: nil,
                isUser: false,
                timestamp: Date(),
                chatId: currentChat?.id
            )
            currentChat?.messages.append(successMessage)
            
            // Add a small delay before showing the note
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Set up note display state and show note
                        noteDisplayState.currentNote = note
                        noteDisplayState.currentTopic = topic
                        noteDisplayState.currentSubtopic = subtopic
                        noteDisplayState.isShowingNote = true
                    }
                }
            }
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
