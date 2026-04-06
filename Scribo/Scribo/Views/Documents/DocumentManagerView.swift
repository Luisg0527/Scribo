import SwiftUI
import UIKit
import PhotosUI
import Photos
import UniformTypeIdentifiers

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
    @State private var isShowingCreateNoteSheet = false
    @State private var createNotePendingPhotos: [PendingNotePhoto] = []
    @State private var createNoteNoteBody: String = ""
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
    @State private var noteName: String = ""
    @State private var hasLoadedInitialData = false
    @State private var isCreatingNewTopic: Bool = false
    /// When the image came from the library (iOS 17+), used for free-tier `photo_library` rows.
    @State private var pendingPhotoLibraryAssetId: String?
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

        for document in filteredDocuments {
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

    /// One grid card per note: prefer the first item that has an image, otherwise the first row.
    private func representativeDocument(for documents: [DocumentItem]) -> DocumentItem? {
        guard !documents.isEmpty else { return nil }
        return documents.first(where: { $0.image != nil }) ?? documents[0]
    }
    
    private func documentGridContent() -> some View {
        // Pinterest-style two-column waterfall layout
        let groups = groupedDocuments
        let leftColumnGroups = groups.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        let rightColumnGroups = groups.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
        
        return HStack(alignment: .top, spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(Array(leftColumnGroups.enumerated()), id: \.element.0) { i, group in
                    let (_, _, documents) = group
                    documentGroupView(documents: documents)
                        .staggeredCardPopIn(delay: Double(i) * 0.055)
                }
            }
            .frame(maxWidth: .infinity)

            LazyVStack(spacing: 12) {
                ForEach(Array(rightColumnGroups.enumerated()), id: \.element.0) { i, group in
                    let (_, _, documents) = group
                    documentGroupView(documents: documents)
                        .staggeredCardPopIn(delay: Double(i) * 0.055 + 0.03)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func documentGroupView(documents: [DocumentItem]) -> some View {
        Group {
            if let doc = representativeDocument(for: documents) {
                documentCard(for: doc)
            }
        }
    }

    private func documentCard(for document: DocumentItem) -> some View {
        DocumentCard(document: document) {
            documentToDelete = document
            showingDeleteAlert = true
        }
        .onTapGesture {
            handleDocumentTap(document)
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
                        
                        // Document Grid — `.refreshable` must be on the ScrollView so pull-to-refresh works
                        ScrollView {
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
                                    Image("nonotes")//<a href="https://www.freepik.com/icon/animal_13822240#fromView=search&page=1&position=67&uuid=d9fba27b-1941-4d85-bd25-683aa1f93068">Icon by Sergei Kokota</a>
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 200, height: 100)
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
                                .padding(.top, 175)
                            } else {
                                documentGridContent()
                            }
                        }
                        .refreshable {
                            isRefreshing = true
                            await loadExistingDocuments()
                            await MainActor.run {
                                isRefreshing = false
                            }
                        }
                        .task {
                            if !hasLoadedInitialData {
                                await loadExistingDocuments()
                                await MainActor.run {
                                    hasLoadedInitialData = true
                                }
                            }
                        }
                        .onChange(of: noteDisplayState.isShowingNote) { oldValue, newValue in
                            if !newValue {
                                Task {
                                    await loadExistingDocuments()
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
        .onChange(of: selectedDocument) { _, newValue in
            guard let url = newValue else { return }
            Task {
                await handlePickedDocumentForCreateNote(url: url)
                await MainActor.run { selectedDocument = nil }
            }
        }
        .photosPicker(isPresented: $isPhotoPickerPresented,
                     selection: $selectedPhotos,
                     maxSelectionCount: 10,
                     matching: .images)
        .onChange(of: selectedPhotos) { oldValue, newValue in
            Task {
                await openCreateNoteSheet(with: newValue)
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
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingScanner) {
            DocumentScannerView { scannedImage in
                handleScannedImage(scannedImage)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $isShowingCreateNoteSheet) {
            CreateNoteSheetView(
                isPresented: $isShowingCreateNoteSheet,
                pendingPhotos: $createNotePendingPhotos,
                noteBody: $createNoteNoteBody,
                dataManager: dataManager,
                classificationService: classificationService,
                onRequestCamera: { isShowingCamera = true },
                onRequestDocument: { isDocumentPickerPresented = true }
            )
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
        defer { isLoadingDocuments = false }
        do {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // Create a Set to track unique document identifiers
            var processedDocumentIds = Set<String>()
            var newDocuments: [DocumentItem] = []
            
            // Load attachments from note_attachments for the current user
            let attachments = try await dataManager.getMyAttachments()
            let imageLikeAttachments = attachments.filter { $0.isImageLike }
            var imageCountPerNote: [UUID: Int] = [:]
            for att in imageLikeAttachments {
                imageCountPerNote[att.note_id, default: 0] += 1
            }

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
                
                if let image = await dataManager.loadUIImage(for: attachment) {
                    let docType = DocumentItem.documentType(forAttachmentKind: attachment.kind)
                    let siblings = imageCountPerNote[note.id] ?? 1
                    let document = DocumentItem(
                        id: UUID(),
                        title: note.title,
                        type: docType,
                        date: dateFormatter.date(from: note.created_at) ?? Date(),
                        image: image,
                        documentURL: nil,
                        category: "\(topic.title) > \(subtopic.title)",
                        topic: topic.title,
                        subtopic: subtopic.title,
                        noteId: note.id,
                        previewText: note.content,
                        siblingImageCount: siblings
                    )
                    newDocuments.append(document)
                    processedDocumentIds.insert(documentId)
                }
            }
            
            // Also include notes that don't have any attachments yet so the
            // Everything tab truly shows all of the user's notes.
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
                        let alreadyPresent = newDocuments.contains { $0.noteId == document.noteId }
                        if !alreadyPresent {
                            newDocuments.append(document)
                        }
                    }
                }
            }
            
            await MainActor.run {
                documents = newDocuments
            }
        } catch is CancellationError {
            return
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled {
                return
            }
            print("❌ Failed to load existing documents: \(error.localizedDescription)")
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load existing documents"))
            }
        }
    }
    
    private func handleSelectedPhoto(_ photo: PhotosPickerItem) async {
        do {
            if let data = try await photo.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let assetId: String? = {
                    if #available(iOS 17, *) {
                        return photo.itemIdentifier
                    }
                    return nil
                }()
                if batchClassification == nil {
                    // First photo in batch - get classification
                    await processAndCategorizeImage(image, type: .photo, photoLibraryAssetId: assetId)
                } else {
                    // Subsequent photos - use existing classification
                    await processImageWithExistingClassification(image, type: .photo, photoLibraryAssetId: assetId)
                }
            }
        } catch {
            print("Failed to load photo: \(error.localizedDescription)")
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load photo: \(error.localizedDescription)"))
            }
        }
    }

    private func openCreateNoteSheet(with items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        var pending: [PendingNotePhoto] = []
        pending.reserveCapacity(items.count)

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { continue }
                let assetId: String? = {
                    if #available(iOS 17, *) {
                        return item.itemIdentifier
                    }
                    return nil
                }()
                pending.append(PendingNotePhoto(image: image, photoLibraryAssetId: assetId))
            } catch {
                print("Failed to load photo: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            presentCreateNoteSheet(photos: pending, noteContent: "")
        }
    }

    /// Universal entry for the “add a new note” sheet (photo library, camera, scan, files).
    /// When `merge` is true and the sheet is already open, photos (and optional text) are appended instead of replacing the draft.
    private func presentCreateNoteSheet(photos: [PendingNotePhoto], noteContent: String = "", merge: Bool = false) {
        if merge && isShowingCreateNoteSheet {
            createNotePendingPhotos.append(contentsOf: photos)
            let t = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                if createNoteNoteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    createNoteNoteBody = noteContent
                } else {
                    createNoteNoteBody += "\n\n" + noteContent
                }
            }
        } else {
            createNotePendingPhotos = photos
            createNoteNoteBody = noteContent
            isShowingCreateNoteSheet = true
        }
    }

    private func handleCameraImage(_ image: UIImage) {
        let entry = PendingNotePhoto(image: image, photoLibraryAssetId: nil)
        presentCreateNoteSheet(photos: [entry], noteContent: "", merge: isShowingCreateNoteSheet)
    }

    private func handleScannedImage(_ image: UIImage) {
        let entry = PendingNotePhoto(image: image, photoLibraryAssetId: nil)
        presentCreateNoteSheet(photos: [entry], noteContent: "", merge: isShowingCreateNoteSheet)
    }

    private func handlePickedDocumentForCreateNote(url: URL) async {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess { url.stopAccessingSecurityScopedResource() }
        }

        let (photos, text) = CreateNoteDraftDocument.load(url: url)

        await MainActor.run {
            if photos.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                alertMessage = "Couldn’t read that file. Try an image, PDF, or plain text."
                showAlert = true
                return
            }
            presentCreateNoteSheet(photos: photos, noteContent: text, merge: isShowingCreateNoteSheet)
        }
    }
    
    private func processAndCategorizeImage(_ image: UIImage, type: DocumentType, photoLibraryAssetId: String? = nil) async {
        isProcessingOCR = true
        processingStatus = "Processing image..."
        
        do {
            if image.jpegData(compressionQuality: 0.8) != nil {
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
                            pendingPhotoLibraryAssetId = photoLibraryAssetId
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
                            pendingPhotoLibraryAssetId = photoLibraryAssetId
                            showTopicPicker = true
                        }
                    }
                } else {
                    // OCR failed - offer manual note creation
                    await MainActor.run {
                        pendingImage = image
                        pendingType = type
                        pendingPhotoLibraryAssetId = photoLibraryAssetId
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
    
    private func processImageWithExistingClassification(_ image: UIImage, type: DocumentType, photoLibraryAssetId: String? = nil) async {
        isProcessingOCR = true
        processingStatus = "Processing image..."
        
        do {
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
                
                // Create document item for UI
                let document = DocumentItem(
                    id: UUID(),
                    title: batchClassification?.note_name ?? "Untitled",
                    type: type,
                    date: Date(),
                    image: image,
                    documentURL: nil,
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
                    
                    _ = try await dataManager.createImageAttachment(
                        for: note.id,
                        imageJPEGData: data,
                        assetLocalIdentifier: photoLibraryAssetId
                    )
                    
                    // Update document with note ID
                    await MainActor.run {
                        if let index = documents.firstIndex(where: { $0.id == document.id }) {
                            documents[index].noteId = note.id
                        }
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
        let libraryAssetId = await MainActor.run { pendingPhotoLibraryAssetId }
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
            guard let data = image.jpegData(compressionQuality: 0.8) else { return }
                
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
                    documentURL: nil,
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
                
                _ = try await dataManager.createImageAttachment(
                    for: note.id,
                    imageJPEGData: data,
                    assetLocalIdentifier: libraryAssetId
                )
                
                // Update document with note ID
                await MainActor.run {
                    if let index = documents.firstIndex(where: { $0.id == document.id }) {
                        documents[index].noteId = note.id
                    }
                }
                
                // Play completion sound
                await MainActor.run {
                    SoundManager.shared.playCompletionSound()
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
            pendingPhotoLibraryAssetId = nil
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
        await performOCR(on: image)
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
                    
                    let note: Note
                    if let nid = document.noteId,
                       let found = subtopicObj.notes.first(where: { $0.id == nid }) {
                        note = found
                    } else if let found = subtopicObj.notes.first(where: { $0.title == document.title }) {
                        note = found
                    } else {
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
                
                let note: Note
                if let nid = document.noteId,
                   let found = subtopicObj.notes.first(where: { $0.id == nid }) {
                    note = found
                } else if let found = subtopicObj.notes.first(where: { $0.title == document.title }) {
                    note = found
                } else {
                    throw AppError.dataError("Note not found")
                }

                try await dataManager.deleteNote(note, from: subtopicObj, from: topicObj)

                await MainActor.run {
                    documents.removeAll { $0.noteId == note.id }
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

struct DocumentManagerView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentManagerView(onOpenMenu: {})
    }
}
