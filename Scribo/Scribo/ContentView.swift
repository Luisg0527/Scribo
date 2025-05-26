import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Note Display State
class NoteDisplayState: ObservableObject {
    @Published var isShowingNote: Bool = false
    @Published var currentNote: Note?
    @Published var currentTopic: Topic?
    @Published var currentSubtopic: Subtopic?
}

struct SidebarView: View {
    @Binding var isShowing: Bool
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showProfile = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var recentNotes: [Note] = []
    @ObservedObject var authManager: AuthManager
    @StateObject private var dataManager = DataManager()
    @StateObject private var chatManager = ChatManager()
    @State private var profileImage: UIImage?
    @State private var isLoadingRecentNotes = false
    @State private var showGhostBlocks = true
    @Binding var chats: [Chat]
    @Binding var currentChat: Chat?
    @State private var isLoadingChats = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile Section
            Button(action: {
                showProfile = true
            }) {
                HStack {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.appAccent1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Profile")
                            .font(.headline)
                            .foregroundColor(.appText)
                        Text("View your profile")
                            .font(.subheadline)
                            .foregroundColor(.appText.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.appHeaderBackground)
            }
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 0) {
                    // Other Tools Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Other Tools")
                            .font(.headline)
                            .foregroundColor(.appText)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        
                        ForEach(["Coming soon..."], id: \.self) { tool in
                            Button(action: {
                                // Tool action
                            }) {
                                HStack {
                                    Image(systemName: "doc.viewfinder")
                                        .foregroundColor(.appAccent1)
                                    Text(tool)
                                        .foregroundColor(.appText)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .background(Color.appCardBackground)
                    
                    // Recent Notes Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Recent Notes")
                            .font(.headline)
                            .foregroundColor(.appText)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        
                        if showGhostBlocks {
                            ForEach(0..<3) { _ in
                                HStack {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.appAccent1.opacity(0.3))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 16)
                                            .cornerRadius(4)
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 80, height: 12)
                                            .cornerRadius(4)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                        } else if !recentNotes.isEmpty {
                            ForEach(recentNotes) { note in
                                recentNoteButton(note)
                            }
                        } else {
                            Text("No recent notes")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.top, 3.0)
                    
                    // Recent Chats Section
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Recent Chats")
                                .font(.headline)
                                .foregroundColor(.appText)
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    do {
                                        // Create a new chat with a timestamp-based title
                                        let dateFormatter = DateFormatter()
                                        dateFormatter.dateFormat = "MMM d, h:mm a"
                                        let timestamp = dateFormatter.string(from: Date())
                                        let newChat = try await chatManager.createChat(title: "Chat \(timestamp)")
                                        await MainActor.run {
                                            chats.append(newChat)
                                            currentChat = newChat
                                        }
                                    } catch {
                                        print("❌ Failed to create new chat: \(error.localizedDescription)")
                                    }
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.appAccent1)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        if isLoadingChats {
                            ForEach(0..<3) { _ in
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .foregroundColor(.appAccent1.opacity(0.3))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 16)
                                            .cornerRadius(4)
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 80, height: 12)
                                            .cornerRadius(4)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                        } else if chats.isEmpty {
                            Text("No recent chats")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(chats.sorted(by: { $0.updatedAt > $1.updatedAt })) { chat in
                                Button(action: {
                                    currentChat = chat
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            do {
                                                try await chatManager.deleteChat(chat.id)
                                                await MainActor.run {
                                                    if let index = chats.firstIndex(where: { $0.id == chat.id }) {
                                                        chats.remove(at: index)
                                                    }
                                                    if currentChat?.id == chat.id {
                                                        currentChat = chats.first
                                                    }
                                                }
                                            } catch {
                                                print("❌ Failed to delete chat: \(error.localizedDescription)")
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 3.0)
                }
            }
            
            // Bottom Buttons
            HStack(spacing: 0) {
                // Sign Out Button
                Button(action: {
                    Task {
                        await authManager.signOut()
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Sign Out")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.appCardBackground)
                }
                
                // Dark Mode Toggle
                Button(action: {
                    withAnimation {
                        isDarkMode.toggle()
                        // Force UI update
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.windows.forEach { window in
                                window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                            }
                        }
                    }
                }) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent1)
                        .frame(width: 44, height: 44)
                        .background(Color.appCardBackground)
                }
            }
        }
        .frame(width: 280)
        .background(Color.appCardBackground)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .fullScreenCover(isPresented: $showProfile) {
            NavigationView {
                ProfileView()
            }
        }
        .onAppear {
            Task {
                await loadProfileImage()
                await loadRecentNotes()
                await loadChats()
            }
            // Set initial color scheme
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                }
            }
        }
        .onChange(of: isShowing) { oldValue, newValue in
            if newValue {
                Task {
                    await loadRecentNotes()
                    await loadChats()
                }
            }
        }
    }
    
    private func loadRecentNotes() async {
        isLoadingRecentNotes = true
        showGhostBlocks = true
        
        // Ensure ghost blocks show for at least 1 second
        try? await Task.sleep(nanoseconds: 0_500_000_000)
        
        do {
            recentNotes = try await dataManager.getRecentNotes()
        } catch {
            print("Failed to load recent notes: \(error.localizedDescription)")
        }
        
        isLoadingRecentNotes = false
        showGhostBlocks = false
    }
    
    private func loadProfileImage() async {
        do {
            let user = try await dataManager.getUserProfile()
            if let avatarUrl = user.avatar_url {
                let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(avatarUrl)
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        profileImage = image
                    }
                }
            }
        } catch {
            print("Failed to load profile image: \(error.localizedDescription)")
        }
    }
    
    private func loadChats() async {
        print("📱 Starting to load chats...")
        isLoadingChats = true
        do {
            let loadedChats = try await chatManager.getChats()
            print("📱 Loaded \(loadedChats.count) chats from database")
            
            if loadedChats.isEmpty {
                print("📱 No chats found, creating welcome chat...")
                do {
                    let welcomeChat = try await chatManager.createChat(title: "Welcome")
                    print("📱 Successfully created welcome chat")
                    await MainActor.run {
                        chats = [welcomeChat]
                        currentChat = welcomeChat
                        print("📱 Updated UI with welcome chat")
                    }
                } catch {
                    print("❌ Failed to create welcome chat: \(error.localizedDescription)")
                }
            } else {
                print("📱 Using existing chats")
                await MainActor.run {
                    chats = loadedChats
                    if currentChat == nil {
                        currentChat = chats.first
                    }
                    print("📱 Updated UI with \(chats.count) chats")
                }
            }
        } catch {
            print("❌ Failed to load chats: \(error.localizedDescription)")
        }
        isLoadingChats = false
        print("📱 Finished loading chats")
    }
    
    private func recentNoteButton(_ note: Note) -> some View {
        Button(action: {
            Task {
                do {
                    // Find the topic and subtopic for this note
                    for topic in dataManager.topics {
                        for subtopic in topic.subtopics {
                            if subtopic.notes.contains(where: { $0.id == note.id }) {
                                try await dataManager.addRecentNote(noteId: note.id.uuidString)
                                await MainActor.run {
                                    noteDisplayState.currentTopic = topic
                                    noteDisplayState.currentSubtopic = subtopic
                                    noteDisplayState.currentNote = note
                                    noteDisplayState.isShowingNote = true
                                    isShowing = false
                                }
                                return
                            }
                        }
                    }
                } catch {
                    print("Error updating recent notes: \(error)")
                }
            }
        }) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.appAccent1)
                VStack(alignment: .leading) {
                    Text(note.title)
                        .foregroundColor(.appText)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Camera View
struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var isShowing: Bool
    @StateObject private var camera = CameraModel()
    @State private var capturedImage: UIImage?
    @State private var showAlert = false
    @State private var flashMode: AVCaptureDevice.FlashMode = .off
    
    var body: some View {
        ZStack {
            if camera.isSessionConfigured {
                CameraPreview(camera: camera)
                    .ignoresSafeArea()
                
                VStack {
                    // Top Controls
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Flash Control
                        Button(action: {
                            switch flashMode {
                            case .off:
                                flashMode = .on
                            case .on:
                                flashMode = .auto
                            case .auto:
                                flashMode = .off
                            @unknown default:
                                flashMode = .off
                            }
                            camera.setFlashMode(flashMode)
                        }) {
                            Image(systemName: flashMode == .off ? "bolt.slash" : 
                                  flashMode == .on ? "bolt.fill" : "bolt.badge.a")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            camera.switchCamera()
                        }) {
                            Image(systemName: "camera.rotate")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            camera.capturePhoto { image in
                                if let image = image {
                                    print("📸 Camera: Photo captured successfully")
                                    capturedImage = image
                                            
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
                                                                    selectedPhoto = PhotosPickerItem(itemIdentifier: asset.localIdentifier)
                                                                    print("📸 Camera: PhotosPickerItem created with identifier: \(asset.localIdentifier)")
                                                            dismiss()
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
                                } else {
                                    print("❌ Camera: Failed to capture photo")
                                }
                            }
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 75, height: 75)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 65, height: 65)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 5)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            } else {
                Color.black
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .alert("Camera Access Required", isPresented: $camera.alert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please allow camera access in Settings to use this feature.")
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        
        // Ensure the preview layer updates when the view's bounds change
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer frame when the view size changes
        DispatchQueue.main.async {
            self.camera.preview.frame = uiView.bounds
        }
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var isSessionConfigured = false
    private var isConfiguring = false
    private var flashMode: AVCaptureDevice.FlashMode = .off
    
    override init() {
        super.init()
        check()
    }
    
    func check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    DispatchQueue.main.async {
                        self?.setUp()
                    }
                }
            }
        case .denied:
            DispatchQueue.main.async {
                self.alert = true
            }
            return
        default:
            return
        }
    }
    
    func setUp() {
        guard !isConfiguring else { return }
        isConfiguring = true
        
        // Stop any existing session
        if session.isRunning {
            session.stopRunning()
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove any existing inputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            // Add video input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                print("Failed to get camera device")
                DispatchQueue.main.async {
                    self.isConfiguring = false
                }
                return
            }
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            // Add photo output
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                self.output.isHighResolutionCaptureEnabled = true
                self.output.maxPhotoQualityPrioritization = .quality
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.isSessionConfigured = true
                self.isConfiguring = false
                
                // Start the session on a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.startRunning()
                }
            }
        }
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        flashMode = mode
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard isSessionConfigured else {
            print("Camera session not configured")
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = self.flashMode
            settings.isHighResolutionPhotoEnabled = true
            settings.photoQualityPrioritization = .quality
            
            self.output.capturePhoto(with: settings, delegate: self)
            self.completion = completion
        }
    }
    
    private var completion: ((UIImage?) -> Void)?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            completion?(nil)
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion?(nil)
            return
        }
        
        completion?(image)
    }
    
    func switchCamera() {
        guard isSessionConfigured, !isConfiguring else { return }
        isConfiguring = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove existing input
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else {
                DispatchQueue.main.async {
                    self.isConfiguring = false
                }
                return
            }
            self.session.removeInput(currentInput)
            
            // Get new camera position
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            
            // Get new device
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                DispatchQueue.main.async {
                    self.isConfiguring = false
                }
                return
            }
            
            // Add new input
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.isConfiguring = false
            }
        }
    }
    
    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

// MARK: - Attachment Menu View
struct AttachmentMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
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
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
            CameraView(selectedPhoto: $selectedPhoto, isShowing: $isShowingCamera)
                .onDisappear {
                    if selectedPhoto != nil {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
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

struct PhotoPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var isShowing: Bool
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Photo Library")
                    .font(.headline)
                    .foregroundColor(.appText)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appAccent1)
                }
            }
            .padding()
            .background(Color.appHeaderBackground)
            
            // System Photo Picker
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appCardBackground)
                        .frame(height: 420)
                        .overlay(
                            VStack {
                                if let selectedImage = selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 420)
                                        .cornerRadius(12)
                                } else {
                                    VStack {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 40))
                                            .foregroundColor(.appAccent1)
                                        Text("Tap to select a photo")
                                            .foregroundColor(.appText)
                                    }
                                }
                            }
                        )
                }
                .padding()
            }
            .onChange(of: selectedPhoto) { oldValue, newValue in
                if let newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }
            }
        }
        .frame(height: 400)
        .background(Color.appBackground)
    }
}

// Add this extension for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @State private var isSidebarShowing: Bool = false
    @State private var showNotebook: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    @StateObject private var dataManager = DataManager()
    @State private var chats: [Chat] = []
    @State private var currentChat: Chat?
    @StateObject private var chatManager = ChatManager()
    @State private var isLoadingChats = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainView
                    .onAppear {
                        Task {
                            await loadChats()
                        }
                    }
            } else if authManager.isResettingPassword {
                NewPasswordView(authManager: authManager)
            } else {
                LoginMethodView(authManager: authManager)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onChange(of: isDarkMode) { oldValue, newValue in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = newValue ? .dark : .light
                }
            }
        }
        .onAppear {
            // Set initial color scheme
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                }
            }
        }
        .onOpenURL { url in
            // Handle deep link for password reset
            print("🔗 Received deep link: \(url)")
            if url.scheme == "scribo" {
                if url.host == "reset-password" {
                    print("✅ Valid reset password URL detected")
                    Task {
                        await authManager.handlePasswordReset(url: url)
                    }
                } else if url.host == "auth-callback" {
                    print("✅ Valid OAuth callback URL detected")
                    Task {
                        await authManager.checkSession()
                    }
                } else {
                    print("❌ Invalid URL host: \(url.host ?? "nil")")
                }
            } else {
                print("❌ Invalid URL scheme: \(url.scheme ?? "nil")")
            }
        }
    }
    
    private var mainView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !showNotebook && !(noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil) {
                        topBarView
                    }
                    
                    mainContentView
                }
                
                sidebarOverlay
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    private var mainContentView: some View {
        Group {
            if showNotebook {
                NotebookView(isPresented: $showNotebook)
                    .environmentObject(noteDisplayState)
            } else if noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil {
                NavigationView {
                    NoteView(note: noteDisplayState.currentNote, isPresented: $showNotebook, dataManager: dataManager)
                        .navigationBarItems(leading: Button(action: {
                            noteDisplayState.isShowingNote = false
                            noteDisplayState.currentNote = nil
                            noteDisplayState.currentTopic = nil
                            noteDisplayState.currentSubtopic = nil
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                        })
                }
            } else {
                ChatView(chats: $chats, currentChat: $currentChat)
            }
        }
    }
    
    private var sidebarOverlay: some View {
        Group {
            if isSidebarShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isSidebarShowing = false
                    }
                
                HStack {
                    SidebarView(isShowing: $isSidebarShowing, authManager: authManager, chats: $chats, currentChat: $currentChat)
                        .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
    }
    
    private var topBarView: some View {
        VStack(spacing: 0) {
            HStack {
                menuButton
                Spacer()
                navigationButton
            }
            .background(Color.appHeaderBackground)
        }
    }
    
    private var menuButton: some View {
        Button(action: {
            withAnimation {
                isSidebarShowing.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20))
                .foregroundColor(.appAccent1)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
    }
    
    private var navigationButton: some View {
        Group {
            if noteDisplayState.isShowingNote {
                Button(action: {
                    noteDisplayState.isShowingNote = false
                    noteDisplayState.currentNote = nil
                    noteDisplayState.currentTopic = nil
                    noteDisplayState.currentSubtopic = nil
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appAccent1)
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 20)
            } else {
                Button(action: {
                    showNotebook = true
                }) {
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent1)
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 20)
            }
        }
    }
    
    private func loadChats() async {
        isLoadingChats = true
        do {
            let loadedChats = try await chatManager.getChats()
            if loadedChats.isEmpty {
                // Create a Welcome chat in the database if no chats exist
                do {
                    let welcomeChat = try await chatManager.createChat(title: "Welcome")
                    await MainActor.run {
                        chats = [welcomeChat]
                        currentChat = welcomeChat
                    }
                } catch {
                    print("❌ Failed to create welcome chat: \(error.localizedDescription)")
                }
            } else {
                await MainActor.run {
                    chats = loadedChats
                    if currentChat == nil {
                        currentChat = chats.first
                    }
                }
            }
        } catch {
            print("Failed to load chats: \(error.localizedDescription)")
        }
        isLoadingChats = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NoteDisplayState())
            .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
            .previewDisplayName("iPhone 16 Pro")
    }
}
