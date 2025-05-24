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
    @State private var profileImage: UIImage?
    @State private var isLoadingRecentNotes = false
    @Binding var chats: [Chat]
    @Binding var currentChat: Chat?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            
            // Dark Mode Toggle
            Button(action: {
                isDarkMode.toggle()
            }) {
                HStack {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(.appAccent1)
                    Text(isDarkMode ? "Dark Mode" : "Light Mode")
                        .foregroundColor(.appText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .padding()
                .background(Color.appCardBackground)
            }
            
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
                
                if isLoadingRecentNotes {
                    ProgressView()
                        .padding()
                } else if recentNotes.isEmpty {
                    Text("No recent notes")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                } else {
                    ForEach(recentNotes) { note in
                        recentNoteButton(note)
                    }
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
                        let newChat = Chat(title: "Chat \(chats.count + 1)")
                        chats.append(newChat)
                        currentChat = newChat
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.appAccent1)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                
                if chats.isEmpty {
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chat.title)
                                    .font(.subheadline)
                                    .foregroundColor(.appText)
                                if !chat.messages.isEmpty {
                                    Text(chat.messages.last?.content ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCardBackground)
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 3.0)
            
            Spacer()
            
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
        }
        .frame(width: 280)
        .background(Color.appCardBackground)
        .fullScreenCover(isPresented: $showProfile) {
            NavigationView {
                ProfileView()
            }
        }
        .onChange(of: noteDisplayState.currentNote) { oldValue, newValue in
            if let note = newValue {
                Task {
                    do {
                        try await dataManager.addRecentNote(noteId: note.id.uuidString)
                        await loadRecentNotes()
                    } catch {
                        print("Error adding recent note: \(error)")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadProfileImage()
                await loadRecentNotes()
            }
        }
        .onChange(of: isShowing) { oldValue, newValue in
            if newValue {
                Task {
                    await loadRecentNotes()
                }
            }
        }
    }
    
    private func loadRecentNotes() async {
        isLoadingRecentNotes = true
        do {
            recentNotes = try await dataManager.getRecentNotes()
        } catch {
            print("Failed to load recent notes: \(error.localizedDescription)")
        }
        isLoadingRecentNotes = false
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
    
    private func recentNoteButton(_ note: Note) -> some View {
        Button(action: {
            noteDisplayState.currentNote = note
            noteDisplayState.isShowingNote = true
            isShowing = false
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
    
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        camera.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        camera.capturePhoto { image in
                            if let image = image {
                                capturedImage = image
                                // Convert UIImage to PhotosPickerItem
                                if let data = image.jpegData(compressionQuality: 0.8) {
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                    try? data.write(to: tempURL)
                                    selectedPhoto = PhotosPickerItem(itemIdentifier: tempURL.absoluteString)
                                }
                                dismiss()
                            }
                        }
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 65, height: 65)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.8), lineWidth: 2)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 30)
            }
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
        
        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak camera] in
            camera?.session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
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
    
    func check() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    self?.setUp()
                }
            }
        case .denied:
            self.alert = true
            return
        default:
            return
        }
    }
    
    func setUp() {
        guard !isConfiguring else { return }
        isConfiguring = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Add video input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                print("Failed to get camera device")
                self.isConfiguring = false
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
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isSessionConfigured = true
                self.isConfiguring = false
            }
        }
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
                self.isConfiguring = false
                return
            }
            self.session.removeInput(currentInput)
            
            // Get new camera position
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            
            // Get new device
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.isConfiguring = false
                return
            }
            
            // Add new input
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
            }
            
            self.session.commitConfiguration()
            self.isConfiguring = false
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
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @State private var isSidebarShowing: Bool = false
    @State private var showNotebook: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var dataManager = DataManager()
    @State private var chats: [Chat] = []
    @State private var currentChat: Chat?
    
    var preferredColorScheme: ColorScheme? {
        isDarkMode ? .dark : .light
    }
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainView
            } else {
                LoginView(authManager: authManager)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            loadSavedChats()
        }
    }
    
    private func loadSavedChats() {
        if let savedChats = UserDefaults.standard.data(forKey: "savedChats"),
           let decodedChats = try? JSONDecoder().decode([Chat].self, from: savedChats) {
            chats = decodedChats
            currentChat = chats.first
        } else {
            let newChat = Chat(title: "Welcome")
            chats = [newChat]
            currentChat = newChat
        }
    }
    
    private var mainView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !showNotebook {
                        topBarView
                    }
                    
                    mainContentView
                }
                
                sidebarOverlay
            }
        }
    }
    
    private var mainContentView: some View {
        Group {
            if noteDisplayState.isShowingNote, let note = noteDisplayState.currentNote {
                NoteView(note: note, isPresented: $noteDisplayState.isShowingNote, dataManager: dataManager)
            } else if showNotebook {
                NotebookView(isPresented: $showNotebook)
                    .environmentObject(noteDisplayState)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NoteDisplayState())
            .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
            .previewDisplayName("iPhone 16 Pro")
    }
}
