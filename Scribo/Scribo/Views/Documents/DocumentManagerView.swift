import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import VisionKit
import Vision
import CoreImage.CIFilterBuiltins

// MARK: - Document Manager View
struct DocumentManagerView: View {
    var onOpenMenu: () -> Void = {}
    @State private var documents: [DocumentItem] = []
    @State private var cardSheetContext: CardSheetContext?
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
    @State private var hasMetMinimumLoadingTime = false
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
    @State private var isShowingCreateNoteSheet = false
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
        // Pinterest-style two-column waterfall layout
        let groups = groupedDocuments
        let leftColumnGroups = groups.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        let rightColumnGroups = groups.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
        
        return HStack(alignment: .top, spacing: 6) {
            LazyVStack(spacing: 6) {
                ForEach(leftColumnGroups, id: \.0) { group in
                    let (noteId, noteTitle, documents) = group
                    documentGroupView(noteId: noteId, noteTitle: noteTitle, documents: documents)
                }
            }
            
            LazyVStack(spacing: 6) {
                ForEach(rightColumnGroups, id: \.0) { group in
                    let (noteId, noteTitle, documents) = group
                    documentGroupView(noteId: noteId, noteTitle: noteTitle, documents: documents)
                }
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
                Button(action: { isPhotoPickerPresented = true }) {
                    Label("Photo Library", systemImage: "photo.fill")
                }
                .accessibilityLabel("Choose from photo library")
                
                Button(action: { isShowingCamera = true }) {
                    Label("Take Photo", systemImage: "camera.fill")
                }
                .accessibilityLabel("Take a new photo")
                
                Button(action: { isShowingScanner = true }) {
                    Label("Scan Document", systemImage: "doc.viewfinder")
                }
                .accessibilityLabel("Scan document")
                
                Button(action: { isDocumentPickerPresented = true }) {
                    Label("Choose Files", systemImage: "doc.fill")
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
                        if isLoadingDocuments || !hasMetMinimumLoadingTime {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .accessibilityLabel("Loading documents")
                            } else {
                                LottieView(name: "Loader cat", loopMode: .loop, playSpeed: 1.0)
                                    .frame(width: 300, height: 200)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .accessibilityLabel("Loading documents animation")
                                    .padding(.top, 130)
                            }
                        } else if filteredDocuments.isEmpty {
                            VStack(spacing: 16) {
                                Image("nonotes")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300, height: 200)
                                    .accessibilityLabel("No notes yet")
                                Text("No notes yet")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.featureCalloutText)
                                    .accessibilityAddTraits(.isHeader)
                                Text("Tap the '+' icon to get started")
                                    .font(.body)
                                    .foregroundColor(.featureCalloutText.opacity(0.7))
                                    .accessibilityLabel("Tap the '+' icon to get started")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 75)
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
                
                // Bottom Bar – "Add a new note" block (tap opens create-note sheet)
                Button(action: { isShowingCreateNoteSheet = true }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADD A NEW NOTE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.featureCalloutAccent)
                        Text("Start typing here...")
                            .font(.body)
                            .foregroundColor(.featureCalloutText.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.white))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, -10)
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
        .task {
            // Ensure the loading animation is visible for at least a short duration
            if !hasMetMinimumLoadingTime {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                hasMetMinimumLoadingTime = true
            }
        }
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
        .fullScreenCover(isPresented: $isShowingCreateNoteSheet) {
            CreateNoteSheetView(isPresented: $isShowingCreateNoteSheet, dataManager: dataManager)
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
        .sheet(item: $cardSheetContext) { ctx in
            NavigationView {
                NoteView(
                    note: ctx.note,
                    isPresented: Binding(
                        get: { cardSheetContext != nil },
                        set: { isPresented in
                            if !isPresented {
                                cardSheetContext = nil
                                Task { await loadExistingDocuments() }
                            }
                        }
                    ),
                    dataManager: dataManager
                )
                .environmentObject(noteDisplayState)
                .onAppear {
                    noteDisplayState.currentNote = ctx.note
                    noteDisplayState.currentTopic = ctx.topic
                    noteDisplayState.currentSubtopic = ctx.subtopic
                }
            }
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
                        noteId: note.id,
                        previewText: note.content
                    )
                    await MainActor.run {
                        documents.append(document)
                        processedDocumentIds.insert(documentId)
                    }
                }
            }
            
            // Also include notes that don't have any attachments yet so the
            // Everything tab truly shows all of the user's notes.
            var noteBackedDocuments: [DocumentItem] = []
            for topic in dataManager.topics {
                for subtopic in topic.subtopics {
                    for note in subtopic.notes {
                        let document = DocumentItem(
                            id: UUID(),
                            title: note.title,
                            type: .document,
                            date: dateFormatter.date(from: note.created_at) ?? Date(),
                            image: nil,
                            documentURL: nil,
                            category: "\(topic.title) > \(subtopic.title)",
                            topic: topic.title,
                            subtopic: subtopic.title,
                            noteId: note.id,
                            previewText: note.content
                        )
                        noteBackedDocuments.append(document)
                    }
                }
            }
            
            await MainActor.run {
                for doc in noteBackedDocuments {
                    let alreadyPresent = documents.contains { $0.noteId == doc.noteId }
                    if !alreadyPresent {
                        documents.append(doc)
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
                        noteId: nil,  // Will be set after note creation
                        previewText: nil
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
                    noteId: nil,
                    previewText: nil
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
                        cardSheetContext = CardSheetContext(note: note, topic: topicObj, subtopic: subtopicObj)
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

// MARK: - Share QR sheet (note/topic – full-screen QR view)
struct ShareQRSheetView: View {
    let title: String
    let inviteURL: String
    @Binding var isPresented: Bool
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Text("Share")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                if let image = generateQRCode(from: inviteURL) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 260, height: 260)
                        .padding(24)
                        .background(Color.white)
                        .cornerRadius(24)
                }
                Spacer()
                HStack(spacing: 32) {
                    shareActionButton(icon: "paintpalette.fill", title: "Customize") {}
                    shareActionButton(icon: "square.and.arrow.up", title: "Share") {
                        presentSystemShare()
                    }
                    shareActionButton(icon: "doc.on.doc", title: "Copy") {
                        UIPasteboard.general.string = inviteURL
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage,
              let cgimg = context.createCGImage(outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgimg)
    }
    
    private func shareActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 60, height: 60)
                    Image(systemName: icon).font(.system(size: 24, weight: .medium)).foregroundColor(.white)
                }
                Text(title).font(.caption).foregroundColor(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }
    
    private func presentSystemShare() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let root = window.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [inviteURL], applicationActivities: nil)
        root.present(vc, animated: true)
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

// MARK: - Create Note Sheet (add photos inside sheet + topic/subtopic picker on save)
struct CreateNoteSheetView: View {
    @Binding var isPresented: Bool
    @ObservedObject var dataManager: DataManager
    var initialTopic: Topic? = nil
    var initialSubtopic: Subtopic? = nil
    @State private var noteContent: String = ""
    @State private var pendingNoteImages: [UIImage] = []
    @State private var selectedPhotosForNote: [PhotosPickerItem] = []
    @State private var isSaving = false
    @State private var showNeedTopicAlert = false
    @State private var showTopicSubtopicPicker = false
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var showConfetti = false
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if showConfetti {
                    LottieView(name: "Confetti", loopMode: .playOnce, playSpeed: 1.0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("ADD A NEW NOTE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.featureCalloutAccent)
                    
                    TextEditor(text: $noteContent)
                        .font(.body)
                        .foregroundColor(Color(.label))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 100)
                        .focused($isTextFieldFocused)
                        .overlay(alignment: .topLeading) {
                            if noteContent.isEmpty {
                                Text("Start typing here...")
                                    .font(.body)
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    
                    // Add photos + preview (inside sheet)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color(.secondaryLabel))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(pendingNoteImages.enumerated()), id: \.offset) { index, img in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 64, height: 64)
                                            .clipped()
                                            .cornerRadius(8)
                                        Button(action: { pendingNoteImages.remove(at: index) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white, Color.black.opacity(0.6))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                                PhotosPicker(
                                    selection: $selectedPhotosForNote,
                                    maxSelectionCount: 20,
                                    matching: .images
                                ) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .foregroundColor(Color(.tertiaryLabel))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            Image(systemName: "photo.badge.plus")
                                                .font(.title2)
                                                .foregroundColor(Color.featureCalloutAccent)
                                        )
                                }
                                .onChange(of: selectedPhotosForNote) { oldValue, newValue in
                                    Task {
                                        for item in newValue {
                                            if let data = try? await item.loadTransferable(type: Data.self),
                                               let image = UIImage(data: data) {
                                                await MainActor.run { pendingNoteImages.append(image) }
                                            }
                                        }
                                        await MainActor.run { selectedPhotosForNote.removeAll() }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 76)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(Color(.label))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Create a new note")
                        .font(.headline)
                        .foregroundColor(Color(.label))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onSaveTapped) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.body)
                                .foregroundColor(Color.featureCalloutAccent)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                isTextFieldFocused = true
                if let topic = initialTopic, let subtopic = initialSubtopic {
                    selectedTopic = topic
                    selectedSubtopic = subtopic
                }
            }
            .alert("Add a topic first", isPresented: $showNeedTopicAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create a topic and subtopic in the Notebook tab, then you can save notes here.")
            }
            .sheet(isPresented: $showTopicSubtopicPicker) {
                TopicSubtopicPickerSheet(
                    dataManager: dataManager,
                    selectedTopic: $selectedTopic,
                    selectedSubtopic: $selectedSubtopic,
                    onConfirm: { saveNoteWithTopicAndSubtopic() },
                    onCancel: { showTopicSubtopicPicker = false }
                )
            }
        }
    }
    
    private func onSaveTapped() {
        let hasContent = !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && pendingNoteImages.isEmpty {
            return
        }
        guard !dataManager.topics.isEmpty else {
            showNeedTopicAlert = true
            return
        }
        if let topic = initialTopic, let subtopic = initialSubtopic {
            saveNoteWithTopicAndSubtopic(topic: topic, subtopic: subtopic)
            return
        }
        showTopicSubtopicPicker = true
    }
    
    private func saveNoteWithTopicAndSubtopic(topic: Topic? = nil, subtopic: Subtopic? = nil) {
        let resolvedTopic = topic ?? selectedTopic
        let resolvedSubtopic = subtopic ?? selectedSubtopic
        guard let topicToUse = resolvedTopic, let subtopicToUse = resolvedSubtopic else { return }
        let content = noteContent
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && pendingNoteImages.isEmpty {
            showTopicSubtopicPicker = false
            return
        }
        isSaving = true
        showTopicSubtopicPicker = false
        Task {
            do {
                let note = try await dataManager.addNote(to: subtopicToUse, in: topicToUse, title: "", content: content)
                for image in pendingNoteImages {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(fileName)
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        try data.write(to: fileURL)
                        let sizeBytes = data.count
                        _ = try await dataManager.createAttachment(
                            for: note.id,
                            storagePath: fileName,
                            mimeType: "image/jpeg",
                            sizeBytes: sizeBytes,
                            kind: "photo"
                        )
                    }
                }
                await MainActor.run {
                    pendingNoteImages.removeAll()
                    isSaving = false
                    selectedTopic = topicToUse
                    selectedSubtopic = subtopicToUse
                    showConfetti = true
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    showConfetti = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Topic / Subtopic Picker (choose where to save the note)
struct TopicSubtopicPickerSheet: View {
    @ObservedObject var dataManager: DataManager
    @Binding var selectedTopic: Topic?
    @Binding var selectedSubtopic: Subtopic?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Topic")) {
                    ForEach(dataManager.topics) { topic in
                        Button(action: {
                            selectedTopic = topic
                            selectedSubtopic = nil
                        }) {
                            HStack {
                                Text(topic.title)
                                Spacer()
                                if selectedTopic?.id == topic.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.featureCalloutAccent)
                                }
                            }
                        }
                    }
                }
                if let topic = selectedTopic {
                    Section(header: Text("Subtopic")) {
                        ForEach(topic.subtopics) { subtopic in
                            Button(action: { selectedSubtopic = subtopic }) {
                                HStack {
                                    Text(subtopic.title)
                                    Spacer()
                                    if selectedSubtopic?.id == subtopic.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color.featureCalloutAccent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save note to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save note") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Color.featureCalloutAccent)
                    .disabled(selectedTopic == nil || selectedSubtopic == nil)
                }
            }
        }
        .onAppear {
            if selectedTopic == nil, let first = dataManager.topics.first {
                selectedTopic = first
                selectedSubtopic = first.subtopics.first
            }
        }
    }
}

struct DocumentManagerView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentManagerView(onOpenMenu: {})
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
