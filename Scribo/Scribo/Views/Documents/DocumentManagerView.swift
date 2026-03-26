import SwiftUI
import UIKit
import PencilKit
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import VisionKit
import Vision
import CoreImage.CIFilterBuiltins
import PDFKit

// MARK: - Staggered card pop-in (scale + rise on appear)
struct StaggeredCardPopInModifier: ViewModifier {
    var delay: Double = 0
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                guard !appeared else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.76).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredCardPopIn(delay: Double = 0) -> some View {
        modifier(StaggeredCardPopInModifier(delay: delay))
    }
}

/// Thrown when classification does not finish within the time limit (Create Note sheet).
private struct ClassificationTimeoutError: Error {}

// MARK: - OCR (shared by document pipeline + Create Note sheet)
fileprivate func performOCR(on image: UIImage) async -> String? {
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

        let sortedObservations = observations.sorted { obs1, obs2 in
            let box1 = obs1.boundingBox
            let box2 = obs2.boundingBox
            return box1.origin.y > box2.origin.y
        }

        var processedLines: [String] = []
        var currentLine: [String] = []
        var lastY: CGFloat = -1
        let yThreshold: CGFloat = 0.05

        for observation in sortedObservations {
            let text = observation.topCandidates(1).first?.string ?? ""
            let box = observation.boundingBox

            if lastY == -1 {
                lastY = box.origin.y
                currentLine.append(text)
            } else if abs(box.origin.y - lastY) < yThreshold {
                currentLine.append(text)
            } else {
                if !currentLine.isEmpty {
                    processedLines.append(currentLine.joined(separator: " "))
                }
                currentLine = [text]
                lastY = box.origin.y
            }
        }

        if !currentLine.isEmpty {
            processedLines.append(currentLine.joined(separator: " "))
        }

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

// MARK: - Everything tab: bottom “add note” bar (presented from ContentView for tab transitions)
struct EverythingTabAddNoteBar: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
            .padding(.bottom, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.white))
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.black)
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 30)
                        }
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 0)
        .padding(.bottom, -10)
    }
}

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
    
    func makeUIViewController(context: Context) -> UIViewController {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = context.coordinator

        // Wrap so it renders edge-to-edge (avoids white/safe-area margins).
        return FullscreenContainerViewController(child: scannerVC)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
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

private final class FullscreenContainerViewController: UIViewController {
    private let childController: UIViewController

    init(child: UIViewController) {
        self.childController = child
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        view.backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(childController)
        childController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childController.view)
        NSLayoutConstraint.activate([
            childController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childController.view.topAnchor.constraint(equalTo: view.topAnchor),
            childController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        childController.didMove(toParent: self)
    }
}

// MARK: - Create note: file → draft photos + text (shared)
enum CreateNoteDraftDocument {
    static func load(url: URL) -> (photos: [PendingNotePhoto], noteContent: String) {
        let ext = url.pathExtension.lowercased()

        if ["jpg", "jpeg", "png", "heic", "gif", "webp", "bmp", "tiff", "tif"].contains(ext) {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                return ([PendingNotePhoto(image: image, photoLibraryAssetId: nil)], "")
            }
        }

        if ext == "pdf" {
            if let image = renderFirstPageThumbnailOfPDF(at: url) {
                return ([PendingNotePhoto(image: image, photoLibraryAssetId: nil)], "")
            }
        }

        if ["txt", "text", "md", "markdown", "csv", "json", "xml"].contains(ext) {
            if let data = try? Data(contentsOf: url) {
                let str = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .utf16)
                    ?? ""
                if !str.isEmpty {
                    return ([], str)
                }
            }
        }

        if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            return ([PendingNotePhoto(image: image, photoLibraryAssetId: nil)], "")
        }

        return ([], "")
    }

    private static func renderFirstPageThumbnailOfPDF(at url: URL) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 800, height: 800), for: .mediaBox)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedDocument: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .text, .plainText, .image, .jpeg, .png, .gif, .webP, .heic, .heif]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
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

// MARK: - Create Note Sheet (compose UI + topic picker on save)
struct PendingNotePhoto: Identifiable {
    let id: UUID
    var image: UIImage
    let photoLibraryAssetId: String?

    init(id: UUID = UUID(), image: UIImage, photoLibraryAssetId: String?) {
        self.id = id
        self.image = image
        self.photoLibraryAssetId = photoLibraryAssetId
    }
}

struct CreateNoteSheetView: View {
    @Binding var isPresented: Bool
    @Binding var pendingPhotos: [PendingNotePhoto]
    @Binding var noteBody: String
    @ObservedObject var dataManager: DataManager
    private let classificationService: TextClassificationService
    var initialTopic: Topic? = nil
    var initialSubtopic: Subtopic? = nil
    var onRequestCamera: (() -> Void)?
    var onRequestDocument: (() -> Void)?

    @State private var selectedPhotosForNote: [PhotosPickerItem] = []
    @State private var isSaving = false
    @State private var showNeedTopicAlert = false
    @State private var showTopicSubtopicPicker = false
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var showConfetti = false
    @State private var isManualNoteMode = false
    @State private var saveErrorMessage: String?
    @State private var isAttachMenuPresented = false
    @State private var isAttachmentsEditorPresented = false
    @FocusState private var isTextFieldFocused: Bool

    private let attachmentSquare: CGFloat = 100

    init(
        isPresented: Binding<Bool>,
        pendingPhotos: Binding<[PendingNotePhoto]>,
        noteBody: Binding<String>,
        dataManager: DataManager,
        classificationService: TextClassificationService = TextClassificationService(
            serverURL: "http://192.168.68.120:8000/classify",
            apiKey: "dev-secret-12345"
        ),
        initialTopic: Topic? = nil,
        initialSubtopic: Subtopic? = nil,
        onRequestCamera: (() -> Void)? = nil,
        onRequestDocument: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._pendingPhotos = pendingPhotos
        self._noteBody = noteBody
        self.dataManager = dataManager
        self.classificationService = classificationService
        self.initialTopic = initialTopic
        self.initialSubtopic = initialSubtopic
        self.onRequestCamera = onRequestCamera
        self.onRequestDocument = onRequestDocument
    }

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

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("ADD A NEW NOTE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.featureCalloutAccent)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    TextEditor(text: $noteBody)
                        .font(.body)
                        .foregroundColor(Color(.label))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 160)
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 15)
                        .padding(.top, 10)
                        .overlay(alignment: .topLeading) {
                            if noteBody.isEmpty {
                                Text("What do you want to talk about?")
                                    .font(.body)
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.horizontal, 20)
                                    .padding(.top, 18)
                                    .allowsHitTesting(false)
                            }
                        }

                    if !pendingPhotos.isEmpty {
                        ZStack(alignment: .topTrailing) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(pendingPhotos) { photo in
                                        pendingAttachmentThumbnail(photo: photo)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .padding(.trailing, 72)
                            }
                            HStack(spacing: 6) {
                                Button {
                                    isAttachmentsEditorPresented = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit attachments")

                                Button {
                                    pendingPhotos.removeAll()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove all attachments")
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 14)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .allowsHitTesting(!isAttachMenuPresented)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composeAccessoryBar
                        .allowsHitTesting(!isAttachMenuPresented)
                }
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
            .onChange(of: selectedPhotosForNote) { _, newValue in
                Task {
                    await ingestPhotosPickerItems(newValue)
                }
            }
            .alert("Add a topic first", isPresented: $showNeedTopicAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create a topic and subtopic in the Notebook tab, then you can save notes here.")
            }
            .alert("Couldn’t save", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
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
            .onChange(of: isAttachMenuPresented) { _, isOpen in
                if isOpen {
                    isTextFieldFocused = false
                }
            }
            .sheet(isPresented: $isAttachMenuPresented) {
                attachOptionsSheet
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
                    .presentationBackground(.clear)
                    .presentationBackgroundInteraction(.enabled)
            }
            .fullScreenCover(isPresented: $isAttachmentsEditorPresented) {
                CreateNoteAttachmentsEditorView(
                    photos: $pendingPhotos,
                    isPresented: $isAttachmentsEditorPresented
                )
            }
        }
    }

    private var composeAccessoryBar: some View {
        HStack(spacing: 14) {
            PhotosPicker(
                selection: $selectedPhotosForNote,
                maxSelectionCount: 20,
                matching: .images
            ) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add from photo library")

            Button {
                isAttachMenuPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More attachments")

            Spacer(minLength: 0)

            Button {
                isManualNoteMode.toggle()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(!isManualNoteMode ? Color.featureCalloutAccent : Color(.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Auto classification")
            .accessibilityHint(isManualNoteMode ? "Off. Tap to enable classification for title and placement." : "On. Tap to save as a manual note.")
            .accessibilityAddTraits(!isManualNoteMode ? .isSelected : [])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var attachOptionsSheet: some View {
        VStack(spacing: 8) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 28),
                    GridItem(.flexible(), spacing: 28),
                    GridItem(.flexible(), spacing: 28)
                ],
                spacing: 32
            ) {
                PhotosPicker(
                    selection: $selectedPhotosForNote,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    attachGridButton(title: "Media", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                Button {
                    isAttachMenuPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onRequestDocument?()
                    }
                } label: {
                    attachGridButton(title: "Document", systemImage: "doc.fill")
                }
                .buttonStyle(.plain)

                Button {
                    isAttachMenuPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onRequestCamera?()
                    }
                } label: {
                    attachGridButton(title: "Photo", systemImage: "camera.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .background(RemoveSheetDropShadow())
    }

    private func attachGridButton(title: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color(.darkGray))
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pendingAttachmentThumbnail(photo: PendingNotePhoto) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: attachmentSquare, height: attachmentSquare)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func ingestPhotosPickerItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var entries: [PendingNotePhoto] = []
        for item in items {
            let assetId: String? = {
                if #available(iOS 17, *) {
                    return item.itemIdentifier
                }
                return nil
            }()
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                entries.append(PendingNotePhoto(image: image, photoLibraryAssetId: assetId))
            }
        }
        await MainActor.run {
            var next = pendingPhotos
            next.append(contentsOf: entries)
            pendingPhotos = next
            selectedPhotosForNote.removeAll()
            isAttachMenuPresented = false
        }
    }
    
    private func onSaveTapped() {
        let hasContent = !noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && pendingPhotos.isEmpty {
            return
        }
        if isManualNoteMode {
            guard !dataManager.topics.isEmpty else {
                showNeedTopicAlert = true
                return
            }
            if let topic = initialTopic, let subtopic = initialSubtopic {
                saveNoteWithTopicAndSubtopic(topic: topic, subtopic: subtopic)
                return
            }
            showTopicSubtopicPicker = true
            return
        }
        Task { await saveWithClassificationPipeline() }
    }
    
    private func saveNoteWithTopicAndSubtopic(topic: Topic? = nil, subtopic: Subtopic? = nil) {
        let resolvedTopic = topic ?? selectedTopic
        let resolvedSubtopic = subtopic ?? selectedSubtopic
        guard let topicToUse = resolvedTopic, let subtopicToUse = resolvedSubtopic else { return }
        let content = noteBody
        let hasContent = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !hasContent && pendingPhotos.isEmpty {
            showTopicSubtopicPicker = false
            return
        }
        isSaving = true
        showTopicSubtopicPicker = false
        Task {
            do {
                let note = try await dataManager.addNote(to: subtopicToUse, in: topicToUse, title: "", content: content)
                for photo in pendingPhotos {
                    guard let data = photo.image.jpegData(compressionQuality: 0.8) else { continue }
                    _ = try await dataManager.createImageAttachment(
                        for: note.id,
                        imageJPEGData: data,
                        assetLocalIdentifier: photo.photoLibraryAssetId
                    )
                }
                await MainActor.run {
                    pendingPhotos = []
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

    /// Default save path: OCR on photos + classify typed + extracted text, then create note (and topics if needed).
    private func saveWithClassificationPipeline() async {
        let trimmedTyped = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        var ocrParts: [String] = []
        for photo in pendingPhotos {
            if let ocr = await performOCR(on: photo.image) {
                let t = ocr.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { ocrParts.append(t) }
            }
        }
        let combinedForClassification = [trimmedTyped, ocrParts.joined(separator: "\n\n")]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
        let combinedTrimmed = combinedForClassification.trimmingCharacters(in: .whitespacesAndNewlines)

        if combinedTrimmed.isEmpty {
            await MainActor.run {
                saveErrorMessage = "Add text or photos with readable text to classify. Or choose Manual note to save without classification."
            }
            return
        }

        await MainActor.run { isSaving = true }

        do {
            let classification = try await classifyTextWithTenSecondTimeout(combinedTrimmed)

            let topicToUse: Topic
            let subtopicToUse: Subtopic

            if let initialT = initialTopic, let initialS = initialSubtopic {
                topicToUse = initialT
                subtopicToUse = initialS
            } else {
                var topicObj = dataManager.topics.first { $0.title == classification.topic }
                if topicObj == nil {
                    topicObj = try await dataManager.addTopic(title: classification.topic)
                }
                guard let topicObj else {
                    throw NSError(domain: "CreateNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve topic"])
                }
                var subtopicObj = topicObj.subtopics.first { $0.title == classification.subtopic }
                if subtopicObj == nil {
                    subtopicObj = try await dataManager.addSubtopic(to: topicObj, title: classification.subtopic)
                }
                guard let subtopicObj else {
                    throw NSError(domain: "CreateNote", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve subtopic"])
                }
                topicToUse = topicObj
                subtopicToUse = subtopicObj
            }

            let noteTitle = classification.note_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Untitled"
                : classification.note_name

            let contentForNote: String = {
                if ocrParts.isEmpty { return noteBody }
                if trimmedTyped.isEmpty { return ocrParts.joined(separator: "\n\n") }
                return trimmedTyped + "\n\n---\n" + ocrParts.joined(separator: "\n\n")
            }()

            let note = try await dataManager.addNote(
                to: subtopicToUse,
                in: topicToUse,
                title: noteTitle,
                content: contentForNote
            )
            for photo in pendingPhotos {
                guard let data = photo.image.jpegData(compressionQuality: 0.8) else { continue }
                _ = try await dataManager.createImageAttachment(
                    for: note.id,
                    imageJPEGData: data,
                    assetLocalIdentifier: photo.photoLibraryAssetId
                )
            }

            await MainActor.run {
                pendingPhotos = []
                isSaving = false
                selectedTopic = topicToUse
                selectedSubtopic = subtopicToUse
                showConfetti = true
                SoundManager.shared.playCompletionSound()
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                showConfetti = false
                isPresented = false
            }
        } catch {
            let lockedToSubtopic = initialTopic != nil && initialSubtopic != nil
            await MainActor.run {
                isSaving = false
                if lockedToSubtopic {
                    saveErrorMessage = "Classification failed or timed out. Try again, or tap Manual note to save without classification."
                } else {
                    isManualNoteMode = true
                    if dataManager.topics.isEmpty {
                        saveErrorMessage = "Classification failed or timed out. Create a topic in the Notebook tab, then save with Manual note."
                    } else {
                        showTopicSubtopicPicker = true
                    }
                }
            }
        }
    }

    /// First successful result wins; sibling task is cancelled. Times out after 10 seconds.
    private func classifyTextWithTenSecondTimeout(_ text: String) async throws -> TextClassificationResponse {
        try await withThrowingTaskGroup(of: TextClassificationResponse.self) { group in
            group.addTask {
                try await classificationService.classifyText(text)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                throw ClassificationTimeoutError()
            }
            guard let result = try await group.next() else {
                throw ClassificationTimeoutError()
            }
            group.cancelAll()
            return result
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

// MARK: - Create note: full-screen attachment editor (carousel + markup)

private enum CreateNoteAttachmentEditTool: Equatable {
    case none
    case draw
    case text
}

private enum CreateNoteAttachmentImageUtils {
    static func drawText(_ text: String, on image: UIImage) -> UIImage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { ctx in
            image.draw(at: .zero)
            let fontSize = max(18, min(image.size.width, image.size.height) * 0.045)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
                .strokeColor: UIColor.black,
                .strokeWidth: -3
            ]
            let inset = fontSize * 0.75
            let rect = CGRect(
                x: inset,
                y: image.size.height * 0.42,
                width: image.size.width - inset * 2,
                height: image.size.height * 0.2
            )
            (trimmed as NSString).draw(
                with: rect,
                options: [.usesLineFragmentOrigin],
                attributes: attrs,
                context: nil
            )
        }
    }
}

private final class PencilMergeHostView: UIView {
    let imageView = UIImageView()
    let canvasView = PKCanvasView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        if #available(iOS 14.0, *) {
            canvasView.tool = PKInkingTool(.pen, color: .white, width: 4)
        }
        addSubview(imageView)
        addSubview(canvasView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let img = imageView.image, img.size.width > 0, img.size.height > 0 else {
            imageView.frame = bounds
            canvasView.frame = bounds
            return
        }
        let rect = AVMakeRect(aspectRatio: img.size, insideRect: bounds)
        imageView.frame = rect
        canvasView.frame = rect
    }

    func setImage(_ image: UIImage) {
        imageView.image = image
        setNeedsLayout()
    }

    func mergeDrawingIntoImage() -> UIImage {
        guard let base = imageView.image else { return UIImage() }
        let drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty else { return base }
        let strokeBounds = canvasView.bounds
        canvasView.drawing = PKDrawing()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)
        let merged = renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            let strokeImage = drawing.image(from: strokeBounds, scale: UIScreen.main.scale)
            strokeImage.draw(in: CGRect(origin: .zero, size: base.size))
        }
        imageView.image = merged
        return merged
    }
}

private struct AttachmentPencilKitOverlay: UIViewRepresentable {
    @Binding var image: UIImage
    var isActive: Bool
    var flushToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PencilMergeHostView {
        PencilMergeHostView()
    }

    func updateUIView(_ uiView: PencilMergeHostView, context: Context) {
        let c = context.coordinator
        let shouldFlush = (c.lastFlush != flushToken) || (c.wasDrawingActive && !isActive)
        if shouldFlush && !uiView.canvasView.drawing.strokes.isEmpty {
            let merged = uiView.mergeDrawingIntoImage()
            image = merged
        }
        if c.lastFlush != flushToken {
            c.lastFlush = flushToken
        }
        c.wasDrawingActive = isActive

        uiView.setImage(image)
        uiView.canvasView.isUserInteractionEnabled = isActive
        uiView.canvasView.isHidden = !isActive
    }

    final class Coordinator {
        var lastFlush: UUID?
        var wasDrawingActive = false
    }
}

private struct CreateNoteAttachmentEditorPage: View {
    @Binding var photo: PendingNotePhoto
    var showDrawOverlay: Bool
    var pencilFlushToken: UUID

    var body: some View {
        ZStack {
            Color.black
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showDrawOverlay {
                AttachmentPencilKitOverlay(
                    image: $photo.image,
                    isActive: true,
                    flushToken: pencilFlushToken
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct CreateNoteAttachmentsEditorView: View {
    @Binding var photos: [PendingNotePhoto]
    @Binding var isPresented: Bool
    @State private var draft: [PendingNotePhoto] = []
    /// Avoid treating initial empty `draft` as “no photos” before `onAppear` copies `photos`.
    @State private var didHydrateDraftFromParent = false
    @State private var selectedPhotoId = UUID()
    @State private var activeTool: CreateNoteAttachmentEditTool = .none
    @State private var pencilFlushToken = UUID()
    @State private var showTextSheet = false
    @State private var textDraft = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()

                if !didHydrateDraftFromParent {
                    ProgressView()
                        .tint(.white)
                } else if draft.isEmpty {
                    Color.black
                        .onAppear { isPresented = false }
                } else {
                    TabView(selection: $selectedPhotoId) {
                        ForEach(Array(draft.enumerated()), id: \.element.id) { index, photo in
                            CreateNoteAttachmentEditorPage(
                                photo: draftPhotoBinding(at: index),
                                showDrawOverlay: activeTool == .draw && photo.id == selectedPhotoId,
                                pencilFlushToken: pencilFlushToken
                            )
                            .tag(photo.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))

                    attachmentEditorBottomBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.94), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        pencilFlushToken = UUID()
                        photos = draft
                        isPresented = false
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white))
                    }
                }
            }
        }
        .onAppear {
            draft = photos
            didHydrateDraftFromParent = true
            if let first = draft.first {
                selectedPhotoId = first.id
            }
        }
        .onChange(of: selectedPhotoId) { _, _ in
            pencilFlushToken = UUID()
        }
        .onChange(of: activeTool) { _, new in
            if new != .draw {
                pencilFlushToken = UUID()
            }
        }
        .onChange(of: draft.count) { _, count in
            if count == 0 {
                isPresented = false
                return
            }
            if !draft.contains(where: { $0.id == selectedPhotoId }) {
                selectedPhotoId = draft.first?.id ?? selectedPhotoId
            }
        }
        .sheet(isPresented: $showTextSheet) {
            NavigationStack {
                Form {
                    TextField("Text on image", text: $textDraft, axis: .vertical)
                        .lineLimit(3...8)
                }
                .navigationTitle("Add text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showTextSheet = false
                            if activeTool == .text { activeTool = .none }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            applyTextOverlay()
                            showTextSheet = false
                            activeTool = .none
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func draftPhotoBinding(at index: Int) -> Binding<PendingNotePhoto> {
        Binding(
            get: { draft[index] },
            set: { draft[index] = $0 }
        )
    }

    private var attachmentEditorBottomBar: some View {
        HStack(spacing: 20) {
            editorBarIconButton(
                systemName: "pencil.tip",
                isSelected: activeTool == .draw,
                accessibilityLabel: "Draw on image"
            ) {
                if activeTool == .draw {
                    pencilFlushToken = UUID()
                    activeTool = .none
                } else {
                    activeTool = .draw
                }
            }

            editorBarIconButton(
                systemName: "textformat",
                isSelected: activeTool == .text,
                accessibilityLabel: "Add text"
            ) {
                textDraft = ""
                showTextSheet = true
                activeTool = .text
            }

            editorBarIconButton(
                systemName: "trash",
                isSelected: false,
                accessibilityLabel: "Delete this image",
                foreground: .red
            ) {
                deleteCurrentDraftPhoto()
            }

            Menu {
                Button("Duplicate this image") {
                    duplicateCurrentPhoto()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("More")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(white: 0.28).opacity(0.95))
        )
    }

    private func editorBarIconButton(
        systemName: String,
        isSelected: Bool,
        accessibilityLabel: String,
        foreground: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.featureCalloutAccent : foreground.opacity(0.92))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func deleteCurrentDraftPhoto() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }) else { return }
        pencilFlushToken = UUID()
        draft.remove(at: idx)
    }

    private func duplicateCurrentPhoto() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }) else { return }
        let base = draft[idx]
        let copy = PendingNotePhoto(
            image: base.image,
            photoLibraryAssetId: base.photoLibraryAssetId
        )
        draft.insert(copy, at: idx + 1)
        selectedPhotoId = copy.id
    }

    private func applyTextOverlay() {
        guard let idx = draft.firstIndex(where: { $0.id == selectedPhotoId }) else { return }
        let t = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft[idx].image = CreateNoteAttachmentImageUtils.drawText(t, on: draft[idx].image)
    }
}

// MARK: - Remove system sheet drop shadow
private struct RemoveSheetDropShadow: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            Self.stripShadowsWalkingSuperviews(from: uiView)
            if let vc = uiView.sheetHostingViewController() {
                Self.stripShadowsWalkingSuperviews(from: vc.view)
                var outer = vc.view.superview
                for _ in 0 ..< 32 {
                    guard let v = outer else { break }
                    Self.stripShadows(on: v)
                    outer = v.superview
                }
            }
        }
    }

    private static func stripShadowsWalkingSuperviews(from start: UIView) {
        var view: UIView? = start
        for _ in 0 ..< 60 {
            guard let v = view else { break }
            Self.stripShadows(on: v)
            view = v.superview
        }
    }

    private static func stripShadows(on view: UIView) {
        view.layer.shadowOpacity = 0
        view.layer.shadowRadius = 0
        view.layer.shadowOffset = .zero
        view.layer.shadowColor = UIColor.clear.cgColor
    }
}

private extension UIView {
    /// UIHostingController that owns this sheet’s SwiftUI content.
    func sheetHostingViewController() -> UIViewController? {
        var r: UIResponder? = self
        while let cur = r {
            if let vc = cur as? UIViewController {
                return vc
            }
            r = cur.next
        }
        return nil
    }
}

struct DocumentManagerView_Previews: PreviewProvider {
    static var previews: some View {
        DocumentManagerView(onOpenMenu: {})
    }
}
