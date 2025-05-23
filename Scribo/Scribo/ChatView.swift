import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import Vision

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
    @State private var classificationService = TextClassificationService(
        serverURL: "http://YOUR_SERVER_IP:8000/classify",
        apiKey: "my-secret-key"
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
                sendMessage()
            }
    }
    
    private var sendButton: some View {
        Button(action: {
            sendMessage()
        }) {
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
        guard let cgImage = image.cgImage else { return nil }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
            guard let observations = request.results else { return nil }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            return recognizedText
        } catch {
            print("OCR Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func sendMessage() {
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
        messages.append(userMessage)
        
        // Clear input
        let currentPhoto = selectedPhoto
        let currentDocument = selectedDocument
        promptText = ""
        selectedPhoto = nil
        selectedDocument = nil
        
        // Add processing message
        let processingMessage = ChatMessage(
            content: "Processing...",
            image: nil,
            document: nil,
            isUser: false,
            timestamp: Date(),
            isProcessing: true
        )
        messages.append(processingMessage)
        
        // Process the photo if one was selected
        if let photo = currentPhoto {
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Process image with OCR
                    let recognizedText = await processImageWithOCR(uiImage)
                    
                    if let text = recognizedText {
                        // Classify the text
                        do {
                            let classification = try await classificationService.classifyText(text)
                            
                            // Add the photo message with OCR results and classification
                            DispatchQueue.main.async {
                                messages.removeLast() // Remove processing message
                                let photoMessage = ChatMessage(
                                    content: """
                                    Extracted text:
                                    \(text)
                                    
                                    Suggested Organization:
                                    Topic: \(classification.topic)
                                    Subtopic: \(classification.subtopic ?? "General")
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
                                
                                // Create the note
                                createNoteFromClassification(classification, content: text)
                            }
                        } catch {
                            // Handle classification error
                            DispatchQueue.main.async {
                                messages.removeLast() // Remove processing message
                                let photoMessage = ChatMessage(
                                    content: "Extracted text:\n\(text)\n\nFailed to classify text: \(error.localizedDescription)",
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
                        DispatchQueue.main.async {
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
            }
        } else if let document = currentDocument {
            // Handle document
            DispatchQueue.main.async {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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
    
    private func createNoteFromClassification(_ classification: ClassificationResponse, content: String) {
        // Find or create the topic
        let topic = dataManager.topics.first { $0.title == classification.topic } ?? {
            let newTopic = Topic(
                id: UUID(),
                user_id: UUID(), // You'll need to get the actual user ID
                title: classification.topic,
                subtopics: [],
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            dataManager.addTopic(title: classification.topic)
            return newTopic
        }()
        
        // Find or create the subtopic
        let subtopic = topic.subtopics.first { $0.title == (classification.subtopic ?? "General") } ?? {
            let newSubtopic = Subtopic(
                id: UUID(),
                topic_id: topic.id,
                title: classification.subtopic ?? "General",
                notes: [],
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            dataManager.addSubtopic(to: topic, title: classification.subtopic ?? "General")
            return newSubtopic
        }()
        
        // Create the note
        dataManager.addNote(
            to: subtopic,
            in: topic,
            title: classification.note_name,
            content: content
        )
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