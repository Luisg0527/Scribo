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

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let image: UIImage?
    let document: DocumentMessage?
    let isUser: Bool
    let timestamp: Date
    var isProcessing: Bool = false
    var error: String? = nil
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isProcessing == rhs.isProcessing &&
        lhs.error == rhs.error
    }
}

struct DocumentMessage: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: String
}

// MARK: - Chat View
struct ChatView: View {
    @State private var promptText: String = ""
    @State private var isTextFieldFocused: Bool = false
    @State private var isAttachmentMenuShowing: Bool = false
    @State private var showActionCards: Bool = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedDocument: URL?
    @State private var isDocumentPickerPresented = false
    @State private var messages: [ChatMessage] = []
    @State private var isProcessingMessage: Bool = false
    @FocusState private var isFocused: Bool
    @State private var animatedText = ""
    @State private var hasAnimatedText = false
    @StateObject private var dataManager = DataManager()
    @State private var isProcessingOCR: Bool = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var currentImageURL: String?
    @State private var classificationService = TextClassificationService(
        serverURL: "http://10.22.149.108:8000/classify",
        apiKey: "dev-secret-12345"
    )
    
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
        .onChange(of: selectedPhoto) { oldValue, newValue in
            withAnimation {
                showActionCards = newValue == nil
            }
        }
        .onChange(of: selectedDocument) { oldValue, newValue in
            withAnimation {
                showActionCards = newValue == nil
            }
        }
    }
    
    // MARK: - Subviews
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    if messages.isEmpty {
                        welcomeView
                    } else {
                        messagesList
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: messages) { _, _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("ThreeDots")
                .frame(width: 97, height: 97)
                .foregroundColor(.appAccent)
            
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
                .foregroundColor(.gray)
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
        ForEach(messages) { message in
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
                        .foregroundColor(.appAccent)
                    Text("Change Photo")
                        .foregroundColor(.appAccent)
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
                    .foregroundColor(.appAccent)
                Text(document.lastPathComponent)
                    .foregroundColor(.appAccent)
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
                .foregroundColor(.appAccent)
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
            .accentColor(.appAccent)
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
                .foregroundColor(.appAccent)
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
    
    private func sendMessage() async {
        guard !promptText.isEmpty || selectedPhoto != nil || selectedDocument != nil else { return }
        
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
            timestamp: Date()
        )
        await MainActor.run {
            messages.append(userMessage)
        }
        
        // Clear input
        let currentPhoto = selectedPhoto
        let currentDocument = selectedDocument
        await MainActor.run {
            promptText = ""
            selectedPhoto = nil
            selectedDocument = nil
        }
        
        // Add processing message
        let processingMessage = ChatMessage(
            content: "Processing...",
            image: nil,
            document: nil,
            isUser: false,
            timestamp: Date(),
            isProcessing: true
        )
        await MainActor.run {
            messages.append(processingMessage)
        }
        
        // Process the photo if one was selected
        if let photo = currentPhoto {
            if let data = try? await photo.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // Process image with OCR
                let recognizedText = await processImageWithOCR(uiImage)
                
                if let text = recognizedText {
                    // Classify the text
                    do {
                        let classification = try await classificationService.classifyText(text)
                        
                        // Add the photo message with OCR results and classification
                        await MainActor.run {
                            messages.removeLast() // Remove processing message
                            let photoMessage = ChatMessage(
                                content: """
                                \(text == "No text could be extracted from this image. Please describe the image content." ? "⚠️ " : "")Extracted text:
                                \(text)
                                
                                Suggested Organization:
                                Topic: \(classification.topic)
                                Subtopic: \(classification.subtopic)
                                Note Title: \(classification.note_name)
                                
                                Classification Scores:
                                \(classification.raw_scores.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
                                """,
                                image: uiImage,
                                document: nil,
                                isUser: false,
                                timestamp: Date()
                            )
                            messages.append(photoMessage)
                        }
                        
                        // Create the note
                        try await createNoteFromClassification(classification)
                    } catch let error as ClassificationError {
                        // Handle specific classification errors
                        let errorMessage: String
                        switch error {
                        case .invalidURL:
                            errorMessage = "Invalid server URL. Please check your configuration."
                        case .networkError(let underlyingError):
                            errorMessage = "Network error: \(underlyingError.localizedDescription)"
                        case .invalidResponse(let statusCode):
                            errorMessage = "Server returned invalid response (Status: \(statusCode))"
                        case .decodingError(let underlyingError):
                            errorMessage = "Failed to decode server response: \(underlyingError.localizedDescription)"
                        case .serverError(let message):
                            errorMessage = "Server error: \(message)"
                        }
                        
                        await MainActor.run {
                            messages.removeLast() // Remove processing message
                            let photoMessage = ChatMessage(
                                content: """
                                Extracted text:
                                \(text)
                                
                                Error during classification:
                                \(errorMessage)
                                """,
                                image: uiImage,
                                document: nil,
                                isUser: false,
                                timestamp: Date()
                            )
                            messages.append(photoMessage)
                        }
                    } catch {
                        // Handle any other errors
                        await MainActor.run {
                            messages.removeLast() // Remove processing message
                            let photoMessage = ChatMessage(
                                content: "Extracted text:\n\(text)\n\nUnexpected error: \(error.localizedDescription)",
                                image: uiImage,
                                document: nil,
                                isUser: false,
                                timestamp: Date()
                            )
                            messages.append(photoMessage)
                        }
                    }
                } else {
                    // Handle OCR failure
                    await MainActor.run {
                        messages.removeLast() // Remove processing message
                        let photoMessage = ChatMessage(
                            content: "Here's the image you shared\n\nFailed to extract text from the image.",
                            image: uiImage,
                            document: nil,
                            isUser: false,
                            timestamp: Date()
                        )
                        messages.append(photoMessage)
                    }
                }
            }
        } else if let document = currentDocument {
            // Handle document
            await MainActor.run {
                messages.removeLast() // Remove processing message
                let documentMessage = ChatMessage(
                    content: "I've received your document: \(document.lastPathComponent)",
                    image: nil,
                    document: DocumentMessage(url: document, name: document.lastPathComponent, type: document.pathExtension),
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(documentMessage)
            }
        } else {
            // Simulate AI response for text-only messages
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                messages.removeLast() // Remove processing message
                let aiResponse = ChatMessage(
                    content: "I understand you want to \(userMessage.content). I'll help you organize this content into appropriate topics and notes.",
                    image: nil,
                    document: nil,
                    isUser: false,
                    timestamp: Date()
                )
                messages.append(aiResponse)
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
            content: messages.last?.content ?? "",  // Use the OCR text from the last message
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
                timestamp: Date()
            )
            messages.append(successMessage)
            
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
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250)
                        .cornerRadius(12)
                }
                
                if let document = message.document {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.appAccent)
                        Text(document.name)
                            .foregroundColor(.appAccent)
                    }
                    .padding(12)
                    .background(Color.appCardBackground)
                    .cornerRadius(16)
                }
                
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.appAccent : Color.appCardBackground)
                        .foregroundColor(message.isUser ? .white : .appText)
                        .cornerRadius(16)
                }
                
                if message.isProcessing {
                    ProgressView()
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
                    .foregroundColor(.gray)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
} 
