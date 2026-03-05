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
struct DocumentItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let type: DocumentType
    let date: Date
    let image: UIImage?
    let documentURL: URL?
    var category: String?
    var topic: String?
    var subtopic: String?
    var noteId: UUID?
    
    static func == (lhs: DocumentItem, rhs: DocumentItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Document Manager View
struct DocumentManagerView: View {
    @Binding var showNotebook: Bool
    var onOpenMenu: () -> Void = {}
    @State private var documents: [DocumentItem] = []
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
    @StateObject private var dataManager = DataManager.shared
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
    @State private var showTopicConfirmation = false
    @State private var pendingClassification: TextClassificationResponse?
    @State private var pendingImage: UIImage?
    @State private var pendingType: DocumentType?
    @State private var selectedTopic: String?
    @State private var selectedSubtopic: String?
    @State private var showTopicPicker = false
    @State private var newTopicName = ""
    @State private var newSubtopicName = ""
    @State private var isRefreshing = false
    @State private var selectedTopicId: UUID?
    @State private var showSubtopicPicker = false
    @State private var documentToDelete: DocumentItem?
    @State private var showingDeleteAlert = false
    @State private var batchClassification: TextClassificationResponse?
    @State private var batchTopic: String?
    @State private var batchSubtopic: String?
    @State private var isProcessingBatch = false
    @State private var expandedNotes: Set<UUID> = []
    @State private var noteName: String = ""
    @State private var hasLoadedInitialData = false
    @State private var isCreatingNewTopic: Bool = false
    @FocusState private var isSearchFocused: Bool

    
    var filteredDocuments: [DocumentItem] {
        documents.filter { document in
            let matchesSearch = searchText.isEmpty || 
                document.title.localizedCaseInsensitiveContains(searchText) ||
                (document.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesFilter = selectedFilter == nil || document.type == selectedFilter
            
            return matchesSearch && matchesFilter
        }
    }
    
    var groupedDocuments: [(UUID, String, [DocumentItem])] {
        var groups: [UUID: (String, [DocumentItem])] = [:]
        
        for document in documents {
            if let noteId = document.noteId {
                if groups[noteId] == nil {
                    groups[noteId] = (document.title, [])
                }
                groups[noteId]?.1.append(document)
            }
        }
        
        return groups.map { ($0.key, $0.value.0, $0.value.1) }
            .sorted { $0.1 < $1.1 }
    }
    
    private func documentGridContent() -> some View {
        // airy 2-column grid
        let columns = [
            GridItem(.flexible(minimum: 170), spacing: 20),
            GridItem(.flexible(minimum: 170), spacing: 20)
        ]
        
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(groupedDocuments, id: \.0) { noteId, noteTitle, documents in
                documentGroupView(noteId: noteId, noteTitle: noteTitle, documents: documents)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expandedNotes)
    }
    
    private func documentGroupView(noteId: UUID, noteTitle: String, documents: [DocumentItem]) -> some View {
        ForEach(documents) { document in
            if documents.count == 1 {
                documentCard(for: document, in: documents, noteId: noteId)
            } else if expandedNotes.contains(noteId) || documents.first?.id == document.id {
                documentCard(for: document, in: documents, noteId: noteId)
            }
        }
    }
    
    private func documentCard(for document: DocumentItem, in documents: [DocumentItem], noteId: UUID) -> some View {
        DocumentCard(document: document) {
            documentToDelete = document
            showingDeleteAlert = true
        }
        .onTapGesture {
            if documents.count > 1 && documents.first?.id == document.id {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if expandedNotes.contains(noteId) {
                        expandedNotes.remove(noteId)
                    } else {
                        expandedNotes.insert(noteId)
                    }
                }
            } else {
                handleDocumentTap(document)
            }
        }
    }
    
    private static let searchBarHeight: CGFloat = 52
    private static let searchBarBackground = Color(hex: "C6C6CB")
    private static let iconFocusDuration: Double = 0.2
    
    /// Top bar: search bar (hamburger inside) + plus outside; when focused, bar goes full width and tap away dismisses
    private var topBarView: some View {
        HStack(alignment: .center, spacing: 8) {
            // Search bar with hamburger inside; same animation in and out
            HStack(spacing: 8) {
                Button(action: onOpenMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.featureCalloutText.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .opacity(isSearchFocused ? 0 : 1)
                .frame(width: isSearchFocused ? 0 : 44, height: Self.searchBarHeight)
                .clipped()
                .allowsHitTesting(!isSearchFocused)
                .animation(.easeInOut(duration: Self.iconFocusDuration), value: isSearchFocused)
                
                TextField("Search my notes...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.featureCalloutText)
                    .multilineTextAlignment(isSearchFocused ? .leading : .center)
                    .focused($isSearchFocused)
            }
            .padding(.leading, isSearchFocused ? 12 : 6)
            .padding(.trailing, 12)
            .frame(height: Self.searchBarHeight)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Self.searchBarBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Self.searchBarBackground.opacity(0.5), lineWidth: 0.5)
            )
            .animation(.easeInOut(duration: Self.iconFocusDuration), value: isSearchFocused)
            .zIndex(1)
            
            Menu {
                Button(action: { isShowingScanner = true }) {
                    Label("Scan", systemImage: "doc.viewfinder")
                }
                .accessibilityLabel("Scan document")
                Button(action: { isPhotoPickerPresented = true }) {
                    Label("Photo", systemImage: "photo.fill")
                }
                .accessibilityLabel("Choose from photo library")
                Button(action: { isDocumentPickerPresented = true }) {
                    Label("Document", systemImage: "doc.fill")
                }
                .accessibilityLabel("Choose from files")
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appAccent1)
                    )
                    .contentShape(Rectangle())
                    .zIndex(0)
            }
            .accessibilityLabel("Add upload")
            .opacity(isSearchFocused ? 0 : 1)
            .frame(width: isSearchFocused ? 0 : 50, height: Self.searchBarHeight)
            .clipped()
            .allowsHitTesting(!isSearchFocused)
            .animation(.easeInOut(duration: Self.iconFocusDuration), value: isSearchFocused)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // One line: hamburger + search + plus
                topBarView
                
                // Content area: tap outside search bar to dismiss focus
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
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
                        .background(Color.clear)
                        .foregroundColor(.featureCalloutText)
                        
                        // Document Grid
                        ScrollView {
                    RefreshableView(isRefreshing: $isRefreshing) {
                        Task {
                            await loadExistingDocuments()
                            await MainActor.run {
                                expandedNotes.removeAll()  // Reset expansion state on refresh
                                isRefreshing = false
                            }
                        }
                    } content: {
                        if isLoadingDocuments {
                            ProgressView("Loading documents...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 40)
                                .foregroundColor(.featureCalloutText)
                                .accessibilityLabel("Loading documents")
                        } else if filteredDocuments.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.featureCalloutText.opacity(0.5))
                                    .padding(.bottom, 8)
                                    .accessibilityHidden(true)
                                
                                Text("Ready to Organize!")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.featureCalloutText)
                                    .accessibilityAddTraits(.isHeader)
                                
                                Text("Upload photos, scan documents, or add files to automatically categorize them into your notebook.")
                                    .font(.body)
                                    .foregroundColor(.featureCalloutText.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 80)
                        } else {
                            documentGridContent()
                        }
                    }
                }
                .refreshable {
                    isRefreshing = true
                    await loadExistingDocuments()
                    await MainActor.run {
                        expandedNotes.removeAll()  // Reset expansion state on refresh
                        isRefreshing = false
                    }
                }
                .task {
                    if !hasLoadedInitialData {
                        await loadExistingDocuments()
                        await MainActor.run {
                            expandedNotes.removeAll()  // Reset expansion state on first load
                            hasLoadedInitialData = true
                        }
                    }
                }
                .onChange(of: noteDisplayState.isShowingNote) { oldValue, newValue in
                    if !newValue {
                        Task {
                            await loadExistingDocuments()
                            await MainActor.run {
                                expandedNotes.removeAll()  // Reset expansion state when returning from note
                            }
                        }
                    }
                }
                .accessibilityLabel("Document list")
                .accessibilityHint("Pull down to refresh")
                    }
                    
                    // Tap away to dismiss search focus
                    if isSearchFocused {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { isSearchFocused = false }
                    }
                }
                
                // Bottom Bar – three aligned buttons: + (left), camera (center), magnifying glass (right)
                ZStack {
                    Color.clear
                        .ignoresSafeArea()
                    
                    HStack(alignment: .center, spacing: 0) {
                        // + Menu (bottom left)
                        Menu {
                            Button(action: { isShowingScanner = true }) {
                                Label("Scan", systemImage: "doc.viewfinder")
                            }
                            .accessibilityLabel("Scan document")
                            
                            Button(action: { isPhotoPickerPresented = true }) {
                                Label("Photo", systemImage: "photo.fill")
                            }
                            .accessibilityLabel("Choose from photo library")
                            
                            Button(action: { isDocumentPickerPresented = true }) {
                                Label("Document", systemImage: "doc.fill")
                            }
                            .accessibilityLabel("Choose from files")
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.appAccent1)
                                        .shadow(color: Color.appAccent1.opacity(0.35), radius: 8, x: 0, y: 4)
                                )
                        }
                        .accessibilityLabel("More options")
                        .accessibilityHint("Double tap to show other upload options")
                        .frame(width: 44, height: 44, alignment: .center)
                        
                        Spacer(minLength: 16)
                        
                        // Camera (center)
                        Button(action: { isShowingCamera = true }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(
                                    Circle()
                                        .fill(Color.appAccent1)
                                        .shadow(color: Color.appAccent1.opacity(0.35), radius: 10, x: 0, y: 6)
                                )
                        }
                        .accessibilityLabel("Take photo")
                        .accessibilityHint("Double tap to open camera")
                        .frame(width: 64, height: 64, alignment: .center)
                        
                        Spacer(minLength: 16)
                        
                        // Magnifying glass / Notebook (bottom right)
                        Button(action: { showNotebook = true }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.appAccent1)
                                        .shadow(color: Color.appAccent1.opacity(0.35), radius: 8, x: 0, y: 4)
                                )
                        }
                        .accessibilityLabel("Open notebook")
                        .accessibilityHint("Double tap to open your notebook")
                        .frame(width: 44, height: 44, alignment: .center)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 80)
            }
            
            // Processing Overlay
            if isProcessingOCR {
                Color.featureCalloutBackground.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.featureCalloutAccent)
                                .accessibilityLabel("Processing")
                            
                            Text(processingStatus)
                                .font(.headline)
                                .foregroundColor(.featureCalloutText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .accessibilityLabel("Processing status: \(processingStatus)")
                        }
                    )
            }
        }
        // Use the global app background instead of a strong gradient
        .background(Color.appBackground)
        .sheet(isPresented: $isDocumentPickerPresented) {
            DocumentPicker(selectedDocument: $selectedDocument)
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
        .onChange(of: isDarkMode) { oldValue, newValue in
            // Reload view when dark mode changes
            Task {
                await loadExistingDocuments()
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
        .sheet(isPresented: $showTopicConfirmation) {
            NavigationView {
                Form {
                    Section(header: Text("Confirm Note Details")
                                .font(.headline)
                                .foregroundColor(.secondary)) {
                        if let topic = selectedTopic, let subtopic = selectedSubtopic {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Topic")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                Text(topic)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Divider()
                                
                                Text("Subtopic")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                Text(subtopic)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note Name")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                            TextField("Enter note name", text: $noteName)
                                .padding(10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .disableAutocorrection(true)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section {
                        Button(action: {
                            if noteName.trimmingCharacters(in: .whitespaces).isEmpty {
                                alertMessage = "Please provide a name for your note."
                                showAlert = true
                            } else {
                                Task {
                                    await confirmAndCreateDocument()
                                }
                                showTopicConfirmation = false
                            }
                        }) {
                            Text("Confirm")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color.accentColor)
                        .buttonStyle(.plain)
                        .cornerRadius(8)
                        
                        Button("Cancel", role: .cancel) {
                            pendingClassification = nil
                            pendingImage = nil
                            pendingType = nil
                            selectedTopic = nil
                            selectedSubtopic = nil
                            selectedTopicId = nil
                            showTopicConfirmation = false
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("Confirm Topic")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
     .sheet(isPresented: $showTopicPicker) {
        NavigationView {
            Form {
                Section(header: Text("Note Information")) {
                    TextField("Note Name", text: $noteName)
                        .font(.headline)
                }
                
                Section(header: Text("Topic")) {
                    Picker("Choose Action", selection: $isCreatingNewTopic) {
                        Text("Select Existing Topic").tag(false)
                        Text("Create New Topic").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if isCreatingNewTopic {
                        TextField("New Topic Name", text: $newTopicName)
                    } else {
                        ForEach(dataManager.topics, id: \.id) { topic in
                            Button {
                                selectedTopicId = (selectedTopicId == topic.id) ? nil : topic.id
                                selectedTopic = topic.title
                                selectedSubtopic = nil
                            } label: {
                                HStack {
                                    Text(topic.title)
                                    Spacer()
                                    if selectedTopicId == topic.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
                
                if !isCreatingNewTopic {
                    if let topicId = selectedTopicId,
                    let topic = dataManager.topics.first(where: { $0.id == topicId }) {
                        Section(header: Text("Subtopic")) {
                            ForEach(topic.subtopics, id: \.id) { subtopic in
                                Button {
                                    selectedSubtopic = (selectedSubtopic == subtopic.title) ? nil : subtopic.title
                                } label: {
                                    HStack {
                                        Text(subtopic.title)
                                        Spacer()
                                        if selectedSubtopic == subtopic.title {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                            if selectedSubtopic == nil {
                                TextField("Or Create New Subtopic", text: $newSubtopicName)
                            }
                        }
                    }
                } else {
                    Section(header: Text("Subtopic")) {
                        TextField("New Subtopic Name", text: $newSubtopicName)
                    }
                }

                Section {
                    Button("Confirm") {
                        if isCreatingNewTopic {
                            selectedTopic = newTopicName
                        }
                        if selectedSubtopic == nil && !newSubtopicName.isEmpty {
                            selectedSubtopic = newSubtopicName
                        }
                        showTopicPicker = false
                        Task {
                            await confirmAndCreateDocument()
                        }
                    }
                    .disabled(noteName.isEmpty || (isCreatingNewTopic ? newTopicName.isEmpty : selectedTopicId == nil) || (selectedSubtopic == nil && newSubtopicName.isEmpty))
                }
            }
            .navigationTitle("Select Topic")
            .navigationBarItems(trailing: Button("Cancel") {
                showTopicPicker = false
            })
        }
    }

        .sheet(isPresented: $showSubtopicPicker) {
            NavigationView {
                Form {
                    if let topicId = selectedTopicId,
                       let topic = dataManager.topics.first(where: { $0.id == topicId }) {
                        Section(header: Text("Select Subtopic for \(topic.title)")) {
                            ForEach(topic.subtopics, id: \.id) { subtopic in
                                Button(action: {
                                    selectedSubtopic = subtopic.title
                                    showSubtopicPicker = false
                                    showTopicPicker = false
                                    Task {
                                        await confirmAndCreateDocument()
                                    }
                                }) {
                                    HStack {
                                        Text(subtopic.title)
                                        Spacer()
                                        if selectedSubtopic == subtopic.title {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section(header: Text("Create New Subtopic")) {
                            TextField("New Subtopic", text: $newSubtopicName)
                            Button("Create New Subtopic") {
                                if !newSubtopicName.isEmpty {
                                    selectedSubtopic = newSubtopicName
                                    showSubtopicPicker = false
                                    showTopicPicker = false
                                    Task {
                                        await confirmAndCreateDocument()
                                    }
                                }
                            }
                            .disabled(newSubtopicName.isEmpty)
                        }
                    }
                }
                .navigationTitle("Select Subtopic")
                .navigationBarItems(trailing: Button("Cancel") {
                    showSubtopicPicker = false
                })
            }
        }
        .alert("Delete Document", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                documentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let document = documentToDelete {
                    Task {
                        await deleteDocument(document)
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this document? This action cannot be undone.")
        }
    }
    
    private func loadExistingDocuments() async {
        isLoadingDocuments = true
        do {
            // Clear existing documents and expanded notes
            await MainActor.run {
                documents.removeAll()
                expandedNotes.removeAll()  // Reset expansion state when reloading
            }
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Create a Set to track unique document identifiers
            var processedDocumentIds = Set<String>()
            
            // Load attachments from note_attachments for the current user
            let attachments = try await dataManager.getMyAttachments()
            
            for attachment in attachments {
                // Find the topic/subtopic/note hierarchy for this attachment's note
                var foundTopic: Topic?
                var foundSubtopic: Subtopic?
                var foundNote: Note?
                
                outerLoop: for topic in dataManager.topics {
                    for subtopic in topic.subtopics {
                        for note in subtopic.notes {
                            if note.id == attachment.note_id {
                                foundTopic = topic
                                foundSubtopic = subtopic
                                foundNote = note
                                break outerLoop
                            }
                        }
                    }
                }
                
                guard let topic = foundTopic,
                      let subtopic = foundSubtopic,
                      let note = foundNote else {
                    continue
                }
                
                let documentId = "\(note.id)-\(attachment.id)"
                guard !processedDocumentIds.contains(documentId) else { continue }
                
                let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(attachment.storage_path)
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
                        subtopic: subtopic.title,
                        noteId: note.id
                    )
                    await MainActor.run {
                        documents.append(document)
                        processedDocumentIds.insert(documentId)
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
                if batchClassification == nil {
                    // First photo in batch - get classification
                    await processAndCategorizeImage(image, type: .photo)
                } else {
                    // Subsequent photos - use existing classification
                    await processImageWithExistingClassification(image, type: .photo)
                }
            }
        } catch {
            print("Failed to load photo: \(error.localizedDescription)")
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
                    do {
                        let classification = try await classificationService.classifyText(text)
                        
                        // Store pending data for confirmation
                        await MainActor.run {
                            pendingClassification = classification
                            pendingImage = image
                            pendingType = type
                            selectedTopic = classification.topic
                            selectedSubtopic = classification.subtopic
                            noteName = ""  // Clear note name to let user input it
                            showTopicConfirmation = true
                        }
                    } catch {
                        // Classification failed - offer manual note creation
                        await MainActor.run {
                            pendingImage = image
                            pendingType = type
                            showTopicPicker = true
                        }
                    }
                } else {
                    // OCR failed - offer manual note creation
                    await MainActor.run {
                        pendingImage = image
                        pendingType = type
                        showTopicPicker = true
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
    
    private func processImageWithExistingClassification(_ image: UIImage, type: DocumentType) async {
        isProcessingOCR = true
        processingStatus = "Processing image..."
        
        do {
            // Save image first
            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: fileURL)
                
                // Create document item for UI
                let document = DocumentItem(
                    id: UUID(),
                    title: batchClassification?.note_name ?? "Untitled",
                    type: type,
                    date: Date(),
                    image: image,
                    documentURL: fileURL,
                    category: "\(batchTopic ?? "") > \(batchSubtopic ?? "")",
                    topic: batchTopic,
                    subtopic: batchSubtopic,
                    noteId: nil  // Will be set after note creation
                )
                
                // Add to documents array
                await MainActor.run {
                    documents.insert(document, at: 0)
                }
                
                // Find or create topic and subtopic
                if let topic = batchTopic, let subtopic = batchSubtopic {
                    var topicObj = dataManager.topics.first { $0.title == topic }
                    if topicObj == nil {
                        topicObj = try await dataManager.addTopic(title: topic)
                    }
                    guard let topicObj = topicObj else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find topic"]) }
                    
                    var subtopicObj = topicObj.subtopics.first { $0.title == subtopic }
                    if subtopicObj == nil {
                        subtopicObj = try await dataManager.addSubtopic(to: topicObj, title: subtopic)
                    }
                    guard let subtopicObj = subtopicObj else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find subtopic"]) }
                    
                    // Create note
                    let note = try await dataManager.addNote(
                        to: subtopicObj,
                        in: topicObj,
                        title: batchClassification?.note_name ?? "Untitled",
                        content: ""
                    )
                    
                    // Create attachment record for this note
                    let dataSize = (image.jpegData(compressionQuality: 0.8))?.count
                    _ = try await dataManager.createAttachment(
                        for: note.id,
                        storagePath: fileName,
                        mimeType: "image/jpeg",
                        sizeBytes: dataSize,
                        kind: type.rawValue
                    )
                    
                    // Update document with note ID
                    await MainActor.run {
                        if let index = documents.firstIndex(where: { $0.id == document.id }) {
                            documents[index].noteId = note.id
                        }
                    }
                    // (Attachments are now handled via note_attachments; no uploads row)
                }
            }
        } catch {
            print("Failed to process image: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "Failed to process image: \(error.localizedDescription)"
                showAlert = true
            }
        }
        
        isProcessingOCR = false
        processingStatus = ""
    }
    
    private func confirmAndCreateDocument() async {
        guard let classification = pendingClassification,
              let image = pendingImage,
              let type = pendingType,
              let topic = selectedTopic,
              let subtopic = selectedSubtopic else {
            return
        }
        
        // Ensure user has provided a note name
        guard !noteName.isEmpty else {
            await MainActor.run {
                alertMessage = "Please provide a name for your note"
                showAlert = true
            }
            return
        }
        
        do {
            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: fileURL)
                
                // Store classification for batch processing
                await MainActor.run {
                    batchClassification = classification
                    batchTopic = topic
                    batchSubtopic = subtopic
                }
                
                // Create document item for UI
                let document = DocumentItem(
                    id: UUID(),
                    title: noteName,  // Use user-provided note name
                    type: type,
                    date: Date(),
                    image: image,
                    documentURL: fileURL,
                    category: "\(topic) > \(subtopic)",
                    topic: topic,
                    subtopic: subtopic,
                    noteId: nil
                )
                
                // Add to documents array
                await MainActor.run {
                    documents.insert(document, at: 0)
                }
                
                // First create or find topic
                var topicObj = dataManager.topics.first { $0.title == topic }
                if topicObj == nil {
                    topicObj = try await dataManager.addTopic(title: topic)
                }
                guard let topicObj = topicObj else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find topic"]) }
                
                // Then create or find subtopic
                var subtopicObj = topicObj.subtopics.first { $0.title == subtopic }
                if subtopicObj == nil {
                    subtopicObj = try await dataManager.addSubtopic(to: topicObj, title: subtopic)
                }
                guard let subtopicObj = subtopicObj else { throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create or find subtopic"]) }
                
                // Create note
                let note = try await dataManager.addNote(
                    to: subtopicObj,
                    in: topicObj,
                    title: noteName,  // Use user-provided note name
                    content: ""
                )
                
                // Create attachment record for this note
                let dataSize = (image.jpegData(compressionQuality: 0.8))?.count
                _ = try await dataManager.createAttachment(
                    for: note.id,
                    storagePath: fileName,
                    mimeType: "image/jpeg",
                    sizeBytes: dataSize,
                    kind: type.rawValue
                )
                
                // Update document with note ID
                await MainActor.run {
                    if let index = documents.firstIndex(where: { $0.id == document.id }) {
                        documents[index].noteId = note.id
                    }
                }
                
                // (Attachments are now handled via note_attachments; no uploads row)
                
                // Play completion sound
                await MainActor.run {
                    SoundManager.shared.playCompletionSound()
                }
            }
        } catch {
            print("Failed to create document: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "Failed to create document: \(error.localizedDescription)"
                showAlert = true
            }
        }
        
        // Clear pending data but keep batch data
        await MainActor.run {
            pendingClassification = nil
            pendingImage = nil
            pendingType = nil
            selectedTopic = nil
            selectedSubtopic = nil
            selectedTopicId = nil
            newTopicName = ""
            newSubtopicName = ""
            noteName = ""
            showTopicConfirmation = false
            showTopicPicker = false
            showSubtopicPicker = false
        }
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

    private func deleteDocument(_ document: DocumentItem) async {
        do {
            // Find the note in the database
            if let topic = document.topic,
               let subtopic = document.subtopic {
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
                
                // Delete the note
                try await dataManager.deleteNote(note, from: subtopicObj, from: topicObj)
                
                // Remove from local documents array
                await MainActor.run {
                    if let index = documents.firstIndex(where: { $0.id == document.id }) {
                        documents.remove(at: index)
                    }
                }
                
                // Show success message
                await MainActor.run {
                    alertMessage = "Document deleted successfully"
                    showAlert = true
                }
            }
        } catch {
            print("❌ Failed to delete document: \(error.localizedDescription)")
            await MainActor.run {
                alertMessage = "Failed to delete document: \(error.localizedDescription)"
                showAlert = true
            }
        }
        
        // Clear the document to delete
        await MainActor.run {
            documentToDelete = nil
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
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? Color.black.opacity(0.9) : .featureCalloutText.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                            ? Color.appAccent1
                            : Color.black.opacity(0.18)
                        )
                )
        }
    }
}

struct DocumentCard: View {
    let document: DocumentItem
    let onDelete: () -> Void
    
    var body: some View {
        let hasCategory = (document.category != nil)
        
        return VStack(alignment: .leading, spacing: 10) {
            if let image = document.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 130)
                    .clipped()
                    .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.featureCalloutButtonBackground)
                    Image(systemName: documentTypeIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.featureCalloutText.opacity(0.6))
                }
                .frame(height: 130)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.featureCalloutText)
                    .lineLimit(2)
                
                Text(document.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.featureCalloutText.opacity(0.65))
                
                if let category = document.category {
                    Text(category)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.appAccent1.opacity(0.15))
                        )
                        .foregroundColor(.appAccent1)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.featureCalloutBackground2)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            hasCategory
                            ? Color.appAccent1.opacity(0.7)
                            : Color.white.opacity(0.04),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var documentTypeIcon: String {
        switch document.type {
        case .photo:
            return "photo.fill"
        case .scanned:
            return "doc.viewfinder"
        case .document:
            return "doc.fill"
        case .camera:
            return "camera.fill"
        }
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
        DocumentManagerView(showNotebook: .constant(false), onOpenMenu: {})
    }
}

// Add RefreshableView
struct RefreshableView<Content: View>: View {
    @Binding var isRefreshing: Bool
    let action: () async -> Void
    let content: Content
    
    init(isRefreshing: Binding<Bool>,
         action: @escaping () async -> Void,
         @ViewBuilder content: () -> Content) {
        self._isRefreshing = isRefreshing
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        if #available(iOS 15.0, *) {
            content
                .refreshable {
                    isRefreshing = true
                    await action()
                    isRefreshing = false
                }
        } else {
            content
        }
    }
} 
