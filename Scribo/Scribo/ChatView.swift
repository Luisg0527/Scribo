import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import VisionKit
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

// MARK: - Document Type
enum DocumentType: String {
    case photo = "photo"
    case scanned = "scanned"
    case document = "document"
    case camera = "camera"
}

// MARK: - Document Item
struct DocumentItem: Identifiable {
    let id: UUID
    let title: String
    let type: DocumentType
    let date: Date
    let image: UIImage?
    let documentURL: URL?
    var category: String?
    var topic: String?
    var subtopic: String?
}

// MARK: - Upload Model
struct Upload: Identifiable, Codable {
    let id: UUID
    let title: String
    let type: String
    let image_url: String?
    let document_url: String?
    let category: String?
    let topic: String?
    let subtopic: String?
    let created_at: String
    let updated_at: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case image_url
        case document_url
        case category
        case topic
        case subtopic
        case created_at
        case updated_at
    }
}

// MARK: - Document Manager View
struct DocumentManagerView: View {
    @State private var documents: [DocumentItem] = []
    @State private var uploads: [Upload] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedDocument: URL?
    @State private var isDocumentPickerPresented = false
    @State private var isShowingCamera = false
    @State private var isShowingScanner = false
    @State private var isProcessingOCR: Bool = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var currentImageURL: String?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var dataManager = DataManager()
    @StateObject private var alertManager = AlertManager()
    @State private var classificationService = TextClassificationService(
        serverURL: "http://10.22.149.108:8000/classify",
        apiKey: "dev-secret-12345"
    )
    @State private var showPhotoLibraryPermissionAlert = false
    @State private var photoLibraryPermissionDenied = false
    @State private var searchText = ""
    @State private var selectedFilter: DocumentType? = nil
    @State private var isPhotoPickerPresented = false
    @State private var isLoadingDocuments = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var filteredDocuments: [DocumentItem] {
        documents.filter { document in
            let matchesSearch = searchText.isEmpty || 
                document.title.localizedCaseInsensitiveContains(searchText) ||
                (document.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesFilter = selectedFilter == nil || document.type == selectedFilter
            
            return matchesSearch && matchesFilter
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding()
            .background(Color.appCardBackground)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterPill(title: "All", isSelected: selectedFilter == nil) {
                        selectedFilter = nil
                    }
                    FilterPill(title: "Photos", isSelected: selectedFilter == .photo) {
                        selectedFilter = .photo
                    }
                    FilterPill(title: "Scanned", isSelected: selectedFilter == .scanned) {
                        selectedFilter = .scanned
                    }
                    FilterPill(title: "Documents", isSelected: selectedFilter == .document) {
                        selectedFilter = .document
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color.appHeaderBackground)
            
            // Document Grid
            ScrollView {
                if isLoadingDocuments {
                    ProgressView("Loading documents...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 40)
                } else if filteredDocuments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                .foregroundColor(.appAccent1)
                            .padding(.bottom, 8)
                        
                        Text("Ready to Organize!")
                            .font(.title2)
                            .fontWeight(.semibold)
                .foregroundColor(.appText)
                        
                        Text("Upload photos, scan documents, or add files to automatically categorize them into your notebook.")
                .font(.body)
                .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.fixed(160), spacing: 16),
                        GridItem(.fixed(160), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredDocuments) { document in
                            DocumentCard(document: document)
                                .onTapGesture {
                                    handleDocumentTap(document)
                                }
                        }
                    }
                    .padding()
                }
            }
            
            // Bottom Bar
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
        .background(Color.appBackground)
        .task {
            await loadExistingDocuments()
            await loadUploads()
        }
        .onChange(of: noteDisplayState.isShowingNote) { oldValue, newValue in
            if !newValue {
                Task {
                    await loadExistingDocuments()
                    await loadUploads()
                }
            }
        }
        .sheet(isPresented: $isDocumentPickerPresented) {
            DocumentPicker(selectedDocument: $selectedDocument)
        }
        .photosPicker(isPresented: $isPhotoPickerPresented,
                     selection: $selectedPhotos,
                     maxSelectionCount: 1,
                     matching: .images)
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                if let photo = newValue.first {
                    await handleSelectedPhoto(photo)
                }
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
        .alert("Upload Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadExistingDocuments() async {
        isLoadingDocuments = true
        do {
            // Clear existing documents
            await MainActor.run {
                documents.removeAll()
            }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Get all topics and their notes
            for topic in dataManager.topics {
                for subtopic in topic.subtopics {
                    for note in subtopic.notes {
                        // Check if note has attachments
                        if let attachmentUrls = note.attachment_urls, !attachmentUrls.isEmpty {
                            for url in attachmentUrls {
                                let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(url)
                                if let data = try? Data(contentsOf: fileURL),
                                   let image = UIImage(data: data) {
                                    let document = DocumentItem(
                                        id: UUID(),
                                        title: note.title,
                                        type: .photo,
                                        date: dateFormatter.date(from: note.created_at) ?? Date(),
                                        image: image,
                                        documentURL: fileURL,
                                        category: "\(topic.title) > \(subtopic.title)",
                                        topic: topic.title,
                                        subtopic: subtopic.title
                                    )
            await MainActor.run {
                                        documents.append(document)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Also load from uploads table
            let uploads = try await dataManager.getUploads()
            for upload in uploads {
                if let imageUrl = upload.image_url {
                    let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(imageUrl)
                    if let data = try? Data(contentsOf: fileURL),
                       let image = UIImage(data: data) {
                        let document = DocumentItem(
                            id: UUID(),
                            title: upload.title,
                            type: DocumentType(rawValue: upload.type) ?? .photo,
                            date: dateFormatter.date(from: upload.created_at) ?? Date(),
                            image: image,
                            documentURL: fileURL,
                            category: upload.category,
                            topic: upload.topic,
                            subtopic: upload.subtopic
                        )
        await MainActor.run {
                            documents.append(document)
                        }
                    }
                }
            }
        } catch {
            print("❌ Failed to load existing documents: \(error.localizedDescription)")
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load existing documents"))
            }
        }
        isLoadingDocuments = false
    }
    
    private func handleSelectedPhoto(_ photo: PhotosPickerItem) async {
        do {
            if let data = try await photo.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await processAndCategorizeImage(image, type: .photo)
            }
        } catch {
            print("❌ Failed to load photo: \(error.localizedDescription)")
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load photo: \(error.localizedDescription)"))
            }
        }
    }
    
    private func handleCameraImage(_ image: UIImage) {
        Task {
            await processAndCategorizeImage(image, type: .camera)
        }
    }
    
    private func handleScannedImage(_ image: UIImage) {
        Task {
            await processAndCategorizeImage(image, type: .scanned)
        }
    }
    
    private func processAndCategorizeImage(_ image: UIImage, type: DocumentType) async {
        isProcessingOCR = true
        
        do {
            // Save image first
                            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                            try data.write(to: fileURL)
                            
                // Process image with OCR
                if let text = await processImageWithOCR(image) {
                                    // Classify the text
                                        let classification = try await classificationService.classifyText(text)
                                        
                    // Create document item
                    let document = DocumentItem(
                        id: UUID(),
                        title: classification.note_name,
                        type: type,
                        date: Date(),
                        image: image,
                        documentURL: fileURL,
                        category: "\(classification.topic) > \(classification.subtopic)",
                        topic: classification.topic,
                        subtopic: classification.subtopic
                    )
                    
                    // Add to documents array
                                        await MainActor.run {
                        documents.insert(document, at: 0)
                    }
                    
                    // Save to Supabase
                    try await saveUpload(
                        title: classification.note_name,
                        type: type.rawValue,
                        imageURL: fileName,
                        documentURL: nil,
                        category: "\(classification.topic) > \(classification.subtopic)",
                        topic: classification.topic,
                        subtopic: classification.subtopic
                    )
                    
                    // Create note in the notebook
                    try await createNoteFromClassification(classification, image: image)
                } else {
                    // Show warning to user when OCR fails
                                        await MainActor.run {
                        alertMessage = "We couldn't extract any text from this image. Please try with a clearer image or add a description manually."
                        showAlert = true
                    }
                    
                    // Create an uncategorized note for development
                                        let defaultClassification = TextClassificationResponse(
                                            topic: "Uncategorized",
                                            subtopic: "General",
                        note_name: "Uncategorized Note \(Date().formatted(date: .abbreviated, time: .shortened))",
                                            raw_scores: [:]
                                        )
                    
                    // Create document item for uncategorized note
                    let document = DocumentItem(
                        id: UUID(),
                        title: defaultClassification.note_name,
                        type: type,
                        date: Date(),
                        image: image,
                        documentURL: fileURL,
                        category: "Uncategorized > General",
                        topic: "Uncategorized",
                        subtopic: "General"
                    )
                    
                    // Add to documents array
                                    await MainActor.run {
                        documents.insert(document, at: 0)
                    }
                    
                    // Save to Supabase
                    try await saveUpload(
                        title: defaultClassification.note_name,
                        type: type.rawValue,
                        imageURL: fileName,
                        documentURL: nil,
                        category: "Uncategorized > General",
                        topic: "Uncategorized",
                        subtopic: "General"
                    )
                    
                    // Create the uncategorized note
                    try await createNoteFromClassification(defaultClassification, image: image)
                            }
                        }
                    } catch {
            print("❌ Failed to process image: \(error.localizedDescription)")
                        await MainActor.run {
                alertMessage = "Failed to process image: \(error.localizedDescription)"
                showAlert = true
            }
        }
        
        isProcessingOCR = false
    }
    
    private func processImageWithOCR(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { 
            print("Failed to get CGImage from UIImage")
            return nil
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
            guard let observations = request.results else { 
                print("No text observations found in image")
                return nil
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            if recognizedText.isEmpty {
                print("OCR returned empty text")
                return nil
            }
            
            return recognizedText
            } catch {
            print("OCR Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createNoteFromClassification(_ classification: TextClassificationResponse, image: UIImage? = nil) async throws {
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
        
        // Save image if provided
        var attachmentUrl: String? = nil
        if let image = image {
            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: fileURL)
                attachmentUrl = fileName
            }
        }
        
        // Create note
        let note = try await dataManager.addNote(
            to: subtopic,
            in: topic,
            title: classification.note_name,
            content: "",  // We'll use the OCR text as content
            attachmentUrls: attachmentUrl != nil ? [attachmentUrl!] : nil
        )
        
        // Update UI on main thread
        await MainActor.run {
            noteDisplayState.currentTopic = topic
            noteDisplayState.currentSubtopic = subtopic
            noteDisplayState.currentNote = note
            noteDisplayState.isShowingNote = true
        }
    }
    
    private func handleDocumentTap(_ document: DocumentItem) {
        // Show document details or open in notebook
        if let topic = document.topic,
           let subtopic = document.subtopic {
            Task {
                do {
                    // Find the topic in the existing topics
                    guard let topicObj = dataManager.topics.first(where: { $0.title == topic }) else {
                        throw AppError.dataError("Topic not found")
                    }
                    
                    // Find the subtopic in the topic's subtopics
                    guard let subtopicObj = topicObj.subtopics.first(where: { $0.title == subtopic }) else {
                        throw AppError.dataError("Subtopic not found")
                    }
                    
                    // Find the note in the subtopic's notes
                    guard let note = subtopicObj.notes.first(where: { $0.title == document.title }) else {
                        throw AppError.dataError("Note not found")
                    }
                    
                    await MainActor.run {
                        noteDisplayState.currentTopic = topicObj
                        noteDisplayState.currentSubtopic = subtopicObj
                        noteDisplayState.currentNote = note
                        noteDisplayState.isShowingNote = true
                    }
                } catch {
                    print("❌ Failed to open document: \(error.localizedDescription)")
                    alertManager.showError(AppError.dataError("Failed to open document: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func loadUploads() async {
        do {
            let response = try await dataManager.getUploads()
            await MainActor.run {
                self.uploads = response
            }
        } catch {
            print("❌ Failed to load uploads: \(error.localizedDescription)")
        }
    }
    
    private func saveUpload(title: String, type: String, imageURL: String?, documentURL: String?, category: String?, topic: String?, subtopic: String?) async throws {
        let upload = UploadRequest(
            title: title,
            type: type,
            image_url: imageURL,
            document_url: documentURL,
            category: category,
            topic: topic,
            subtopic: subtopic
        )
        
        let newUpload = try await dataManager.createUpload(upload)
        await MainActor.run {
            uploads.insert(newUpload, at: 0)
        }
    }
}

// MARK: - Supporting Views
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appAccent1 : Color.appCardBackground)
                .foregroundColor(isSelected ? .white : .appText)
                .cornerRadius(20)
        }
    }
}

struct DocumentCard: View {
    let document: DocumentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = document.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipped()
            } else {
                        Image(systemName: "doc.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                            .foregroundColor(.appAccent1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appText)
                    .lineLimit(1)
                
                if let category = document.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.appTextSecondary)
                }
                
                Text(document.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 160)
        .background(Color.appCardBackground)
        .cornerRadius(12)
        .shadow(color: Color.appShadow, radius: 8, x: 0, y: 4)
    }
}

struct UploadButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                                        .font(.caption)
            }
            .foregroundColor(.appAccent1)
            .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
            .background(Color.appCardBackground)
            .cornerRadius(12)
        }
    }
}

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScanComplete: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = context.coordinator
        return scannerVC
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScanComplete: (UIImage) -> Void
        
        init(onScanComplete: @escaping (UIImage) -> Void) {
            self.onScanComplete = onScanComplete
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let image = scan.imageOfPage(at: 0)
            onScanComplete(image)
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Scanner error: \(error.localizedDescription)")
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedDocument: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .text, .plainText])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedDocument = url
        }
    }
}

struct DocumentManagerView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentManagerView()
    }
} 
