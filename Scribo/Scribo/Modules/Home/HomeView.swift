import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation

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

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @State private var profileImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Image Section
                    VStack {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.appAccent, lineWidth: 3)
                                )
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.appAccent)
                        }
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                        }
                        .onChange(of: selectedPhoto) { oldValue, newValue in
                            if let newValue {
                                Task {
                                    if let data = try? await newValue.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        profileImage = uiImage
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top)
                    
                    // Profile Information
                    VStack(spacing: 20) {
                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            TextField("Your name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.appText)
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            TextField("Your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.appText)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Bio Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            TextEditor(text: $bio)
                                .frame(height: 100)
                                .padding(4)
                                .background(Color.appCardBackground)
                                .cornerRadius(8)
                                .foregroundColor(.appText)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preferences")
                            .font(.headline)
                            .foregroundColor(.appText)
                        
                        // Dark Mode Toggle
                        Toggle(isOn: $isDarkMode) {
                            HStack {
                                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(.appAccent)
                                Text("Dark Mode")
                                    .foregroundColor(.appText)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .appAccent))
                    }
                    .padding()
                    .background(Color.appCardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.appAccent)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.headline)
                        .foregroundColor(.appText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save profile changes
                        dismiss()
                    }
                    .foregroundColor(.appAccent)
                }
            }
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

// MARK: - Main Content View
struct HomeView: View {
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @EnvironmentObject private var authManager: AuthManager
    @State private var promptText: String = ""
    @State private var isSidebarShowing: Bool = false
    @State private var isAttachmentMenuShowing: Bool = false
    @State private var showActionCards: Bool = true
    @State private var showNotebook: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedDocument: URL?
    @State private var isDocumentPickerPresented = false
    @State private var messages: [ChatMessage] = []
    @State private var isProcessingMessage: Bool = false
    @FocusState private var isFocused: Bool
    @State private var animatedText = ""
    @State private var hasAnimatedText = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    let welcomeMessage = "Hello! What can I help you with?"
    
    var preferredColorScheme: ColorScheme? {
        isDarkMode ? .dark : .light
    }
    
    var body: some View {
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
            .fileImporter(
                isPresented: $isDocumentPickerPresented,
                allowedContentTypes: [.pdf, .text, .plainText, .rtf, .rtfd],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedDocument = url
                    }
                case .failure(let error):
                    Logger.error("Error selecting document: \(error.localizedDescription)")
                }
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
    
    // MARK: - Subviews
    private var mainContentView: some View {
        Group {
            if noteDisplayState.isShowingNote, let note = noteDisplayState.currentNote {
                NoteView(note: note, isPresented: $noteDisplayState.isShowingNote)
            } else if showNotebook {
                notebookView
            } else {
                chatView
            }
        }
    }
    
    private var chatView: some View {
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
        .background(Color.appBackground)
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
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isAttachmentMenuShowing.toggle()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appAccent)
                }
                
                TextField("Type a message...", text: $promptText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(Color.appCardBackground)
                    .cornerRadius(20)
                    .focused($isFocused)
                
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appAccent)
                }
                .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhoto == nil && selectedDocument == nil)
            }
            .padding()
            .background(Color.appHeaderBackground)
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
    
    private var attachmentMenuView: some View {
        Group {
            if isAttachmentMenuShowing {
                AttachmentMenuView(
                    isShowing: $isAttachmentMenuShowing,
                    selectedPhoto: $selectedPhoto,
                    selectedDocument: $selectedDocument,
                    isDocumentPickerPresented: $isDocumentPickerPresented
                )
            }
        }
    }
    
    private var sidebarOverlay: some View {
        Group {
            if isSidebarShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarShowing = false
                        }
                    }
                
                HStack {
                    SidebarView(
                        isShowing: $isSidebarShowing,
                        authManager: authManager
                    )
                    .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
        }
    }
    
    private var topBarView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSidebarShowing.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent)
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 26)
                
                Spacer()
                
                Group {
                    if noteDisplayState.isShowingNote {
                        Button(action: {
                            noteDisplayState.isShowingNote = false
                            noteDisplayState.currentNote = nil
                            noteDisplayState.currentTopic = nil
                            noteDisplayState.currentSubtopic = nil
                            isAttachmentMenuShowing = false
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
            .background(Color.appHeaderBackground)
        }
    }
    
    private var notebookView: some View {
        NotebookView(isPresented: $showNotebook, authManager: authManager)
    }
    
    // MARK: - Helper Methods
    private func animateText() {
        let text = welcomeMessage
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if index < text.count {
                animatedText += String(text[text.index(text.startIndex, offsetBy: index)])
                index += 1
            } else {
                timer.invalidate()
                hasAnimatedText = true
            }
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
                    // Add the photo message
                    DispatchQueue.main.async {
                        messages.removeLast() // Remove processing message
                        let photoMessage = ChatMessage(
                            content: "Here's the image you shared",
                            image: uiImage,
                            document: nil,
                            isUser: false,
                            timestamp: Date()
                        )
                        messages.append(photoMessage)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(NoteDisplayState())
            .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
            .previewDisplayName("iPhone 16 Pro")
    }
}
