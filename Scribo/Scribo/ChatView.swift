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
    let note_id: UUID
    
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
        case note_id
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
    @State private var processingStatus: String = ""
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var currentImageURL: String?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var dataManager = DataManager()
    @StateObject private var alertManager = AlertManager()
    @State private var classificationService = TextClassificationService(
        serverURL: "http://192.168.68.120:8000/classify",
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
        ZStack {
            VStack(spacing: 0) {
                // Search and Filter Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search uploads...", text: $searchText)
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
                .foregroundColor(.appText)
                
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
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.bottom, 8)
                            
                            Text("Ready to Organize!")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray.opacity(0.7))
                            
                            Text("Upload photos, scan documents, or add files to automatically categorize them into your notebook.")
                                .font(.body)
                                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 80)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.fixed(160), spacing: 36),
                            GridItem(.fixed(160), spacing: 36)
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
                        Button(action: { isShowingScanner = true }) {
                            Label("Scan", systemImage: "doc.viewfinder")
                        }
                        Button(action: { isShowingCamera = true }) {
                            Label("Camera", systemImage: "camera.fill")
                        }
                        Button(action: { isPhotoPickerPresented = true }) {
                            Label("Photo", systemImage: "photo.fill")
                        }
                        
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.appAccent1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 3)
                    
                    Spacer()
                }
                .padding()
                .background(Color.appHeaderBackground.opacity(0.8))
            }
            
            // Processing Overlay
            if isProcessingOCR {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                            .overlay(
                        VStack(spacing: 16) {
                                ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                    
                            Text(processingStatus)
                                .font(.headline)
                            .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    )
            }
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
        processingStatus = "Processing image..."
        
        do {
            // Save image first
                            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                            try data.write(to: fileURL)
                            
                // Process image with OCR
                processingStatus = "Extracting text..."
                if let text = await processImageWithOCR(image) {
                                    // Classify the text
                    processingStatus = "Categorizing content..."
                                        let classification = try await classificationService.classifyText(text)
                                        
                    // Create document item for UI
                    processingStatus = "Creating document..."
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
                    
                    // First create or find topic
                    var topic = dataManager.topics.first { $0.title == classification.topic }
                    if topic == nil {
                        topic = try await dataManager.addTopic(title: classification.topic)
                    }
                    guard let topic = topic else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find topic"]) }
                    
                    // Then create or find subtopic
                    var subtopic = topic.subtopics.first { $0.title == classification.subtopic }
                    if subtopic == nil {
                        subtopic = try await dataManager.addSubtopic(to: topic, title: classification.subtopic)
                    }
                    guard let subtopic = subtopic else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find subtopic"]) }
                    
                    // Create note with the image
                    let note = try await dataManager.addNote(
                        to: subtopic,
                        in: topic,
                        title: classification.note_name,
                        content: text,
                        attachmentUrls: [fileName]
                    )
                    
                    // Now create the upload with the note_id
                    try await saveUpload(
                        title: classification.note_name,
                        type: type.rawValue,
                        imageURL: fileName,
                        documentURL: nil,
                        category: "\(classification.topic) > \(classification.subtopic)",
                        topic: classification.topic,
                        subtopic: classification.subtopic,
                        noteId: note.id
                    )
                    
                    // Update UI
                                        await MainActor.run {
                        noteDisplayState.currentTopic = topic
                        noteDisplayState.currentSubtopic = subtopic
                        noteDisplayState.currentNote = note
                        noteDisplayState.isShowingNote = true
                    }
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
                    
                    // Create topic, subtopic, and note for uncategorized
                    var topic = dataManager.topics.first { $0.title == "Uncategorized" }
                    if topic == nil {
                        topic = try await dataManager.addTopic(title: "Uncategorized")
                    }
                    guard let topic = topic else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find topic"]) }
                    
                    var subtopic = topic.subtopics.first { $0.title == "General" }
                    if subtopic == nil {
                        subtopic = try await dataManager.addSubtopic(to: topic, title: "General")
                    }
                    guard let subtopic = subtopic else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find subtopic"]) }
                    
                    let note = try await dataManager.addNote(
                        to: subtopic,
                        in: topic,
                        title: defaultClassification.note_name,
                        content: "",
                        attachmentUrls: [fileName]
                    )
                    
                    // Create upload with note_id
                    try await saveUpload(
                        title: defaultClassification.note_name,
                        type: type.rawValue,
                        imageURL: fileName,
                        documentURL: nil,
                        category: "Uncategorized > General",
                        topic: "Uncategorized",
                        subtopic: "General",
                        noteId: note.id
                    )
                    
                    // Update UI
                    await MainActor.run {
                        noteDisplayState.currentTopic = topic
                        noteDisplayState.currentSubtopic = subtopic
                        noteDisplayState.currentNote = note
                        noteDisplayState.isShowingNote = true
                                }
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
        processingStatus = ""
    }
    
    private func processImageWithOCR(_ image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { 
            print("Failed to get CGImage from UIImage")
            return nil
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.customWords = ["Swift", "SwiftUI", "Xcode", "iOS", "macOS", "UIKit", "AppKit"]
        
        do {
            try requestHandler.perform([request])
            guard let observations = request.results else { 
                print("No text observations found in image")
                return nil
            }
            
            // Sort observations by vertical position (top to bottom)
            let sortedObservations = observations.sorted { obs1, obs2 in
                let box1 = obs1.boundingBox
                let box2 = obs2.boundingBox
                return box1.origin.y > box2.origin.y
            }
            
            // Process text with improved formatting
            var processedLines: [String] = []
            var currentLine: [String] = []
            var lastY: CGFloat = -1
            let yThreshold: CGFloat = 0.05 // Threshold for considering text on the same line
            
            for observation in sortedObservations {
                let text = observation.topCandidates(1).first?.string ?? ""
                let box = observation.boundingBox
                
                if lastY == -1 {
                    lastY = box.origin.y
                    currentLine.append(text)
                } else if abs(box.origin.y - lastY) < yThreshold {
                    // Text is on the same line
                    currentLine.append(text)
                } else {
                    // New line detected
                    if !currentLine.isEmpty {
                        processedLines.append(currentLine.joined(separator: " "))
                        currentLine = [text]
                        lastY = box.origin.y
                    }
                }
            }
            
            // Add the last line
            if !currentLine.isEmpty {
                processedLines.append(currentLine.joined(separator: " "))
            }
            
            // Join lines with proper spacing
            let processedText = processedLines.joined(separator: "\n")
            
            if processedText.isEmpty {
                print("OCR returned empty text")
                return nil
            }
            
            return processedText
        } catch {
            print("OCR Error: \(error.localizedDescription)")
            return nil
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
    
    private func saveUpload(title: String, type: String, imageURL: String?, documentURL: String?, category: String?, topic: String?, subtopic: String?, noteId: UUID) async throws {
        let upload = UploadRequest(
            title: title,
            type: type,
            image_url: imageURL,
            document_url: documentURL,
            category: category,
            topic: topic,
            subtopic: subtopic,
            note_id: noteId
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
                    .frame(width: 180, height: 160)
                    .clipped()
            } else {
                        Image(systemName: "doc.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 160)
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
        .frame(width: 180)
        .background(Color.clear)
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
