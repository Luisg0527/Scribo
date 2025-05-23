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

// MARK: - Color Constants
extension Color {
    static let appBackground = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : // Dark mode background
            UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)   // Light mode background
    })
    
    static let appCardBackground = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0) : // Dark mode card
            UIColor(red: 1, green: 1, blue: 1, alpha: 1.0)            // Light mode card
    })
    
    static let appHeaderBackground = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1.0) : // Dark mode header
            UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0)   // Light mode header
    })
    
    static let appText = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1.0) :   // Dark mode text
            UIColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)     // Light mode text
    })
    
    static let appAccent = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ?
            UIColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1.0) :    // Dark mode accent
            UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)      // Light mode accent
    })
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
                            .foregroundColor(.appAccent)
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
                        .foregroundColor(.appAccent)
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
                                .foregroundColor(.appAccent)
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
                    .foregroundColor(.appAccent)
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
    
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        camera.takePicture()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 65, height: 65)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        camera.switchCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding()
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
        .onChange(of: camera.photo) { oldValue, newValue in
            if let image = newValue {
                // Convert UIImage to PhotosPickerItem
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("camera_photo.jpg")
                    try? data.write(to: tempURL)
                    selectedPhoto = PhotosPickerItem(itemIdentifier: tempURL.absoluteString)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
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
    @Published var photo: UIImage?
    @Published var isCameraAuthorized = false
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
            setUp()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    DispatchQueue.main.async {
                        self.isCameraAuthorized = true
                        self.setUp()
                    }
                }
            }
        default:
            isCameraAuthorized = false
            alert = true
            return
        }
    }
    
    func setUp() {
        do {
            self.session.beginConfiguration()
            
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            let input = try AVCaptureDeviceInput(device: device!)
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func takePicture() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            DispatchQueue.main.async {
                withAnimation { self.isTaken.toggle() }
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        self.photo = UIImage(data: imageData)
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        // Remove existing input
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        session.removeInput(currentInput)
        
        // Get new camera position
        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        
        // Get new device
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else { return }
        
        // Add new input
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        session.commitConfiguration()
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
        camera.session.startRunning()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
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
        }
    }
    
    private func menuItemView(_ item: (String, String, String)) -> some View {
        HStack(spacing: 16) {
            Image(systemName: item.0)
                .font(.system(size: 24))
                .foregroundColor(.appAccent)
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
                        .foregroundColor(.appAccent)
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
                                            .foregroundColor(.appAccent)
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
                ChatView()
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
                    SidebarView(isShowing: $isSidebarShowing, authManager: authManager)
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
                .foregroundColor(.appAccent)
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
                        .foregroundColor(.appAccent)
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 20)
            } else {
                Button(action: {
                    showNotebook = true
                }) {
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent)
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
