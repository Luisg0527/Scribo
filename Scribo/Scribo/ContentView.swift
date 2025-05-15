import SwiftUI
import PhotosUI
import Photos

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let image: UIImage?
    let isUser: Bool
    let timestamp: Date
}

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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Section
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.appAccent)
                
                VStack(alignment: .leading) {
                    Text("Profile")
                        .font(.headline)
                        .foregroundColor(.appText)
                    Text("View your profile")
                        .font(.subheadline)
                        .foregroundColor(.appText.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: {
                    // Profile settings action
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundColor(.appText)
                        .rotationEffect(.degrees(90))
                }
            }
            .padding()
            .background(Color.appHeaderBackground)
            
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
                
                ForEach(["Scanner"], id: \.self) { tool in
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
            
            // Previous Chats Section
            VStack(alignment: .leading, spacing: 0) {
                Text("Previous Chats")
                    .font(.headline)
                    .foregroundColor(.appText)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                ForEach(["CS Notes Discussion", "Math Summary", "History Review"], id: \.self) { chat in
                    Button(action: {
                        // Chat action
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.appAccent)
                            Text(chat)
                                .foregroundColor(.appText)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.appCardBackground)
            
            Spacer()
        }
        .frame(width: 280)
        .background(Color.appBackground)
    }
}

struct AttachmentMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    
    let menuItems = [
        ("doc.fill", "Document", "Share a document"),
        ("photo.fill", "Photos", "Share photos"),
        ("camera.fill", "Camera", "Take a photo"),
        ("location.fill", "Location", "Share your location"),
        ("person.fill", "Contact", "Share a contact")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Menu Items
            VStack(spacing: 0) {
                ForEach(menuItems, id: \.1) { item in
                    if item.1 == "Photos" {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
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
                    } else {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }) {
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
                }
            }
            .background(Color.appHeaderBackground)
        }
        .frame(height: 330)
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

struct ContentView: View {
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @State private var promptText: String = ""
    @State private var isTextFieldFocused: Bool = false
    @State private var isSidebarShowing: Bool = false
    @State private var isAttachmentMenuShowing: Bool = false
    @State private var showActionCards: Bool = true
    @State private var showNotebook: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var messages: [ChatMessage] = []
    @FocusState private var isFocused: Bool
    @State private var animatedText = ""
    @State private var hasAnimatedText = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    let fullText = "Hello, what can I help you with?"
    
    // Action buttons data
    private let actionButtons = [
        "Explain my notes of CS",
        "Summarize this text",
        "Create flashcards",
        "Generate quiz questions",
        "Find key concepts",
        "Compare and contrast",
        "Explain like I'm 5"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        isFocused = false
                    }
                
                VStack(spacing: 0) {
                    // Main Content
                    if noteDisplayState.isShowingNote, let note = noteDisplayState.currentNote {
                        NoteView(note: note, isPresented: $noteDisplayState.isShowingNote)
                    } else if showNotebook {
                        NotebookView(isPresented: $showNotebook)
                            .environmentObject(noteDisplayState)
                    } else if messages.isEmpty {
                        // Welcome View
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image("ThreeDots")
                                .frame(width: 97, height: 97)
                                .foregroundColor(.appAccent)
                            
                            Text(hasAnimatedText ? fullText : animatedText)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.appText)
                                .onAppear {
                                    if !hasAnimatedText {
                                        animateText()
                                    }
                                }
                            
                            Spacer()
                            
                            // Action Cards
                            if showActionCards {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // First set of cards
                                        ForEach(actionButtons, id: \.self) { action in
                                            Button(action: {
                                                promptText = action
                                                isFocused = true
                                                showActionCards = false
                                            }) {
                                                Text(action)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.appText)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(width: 220)
                                                    .frame(height: 50)
                                                    .background(Color.appCardBackground)
                                                    .cornerRadius(13)
                                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            }
                                        }
                                        
                                        // Duplicate set of cards to create infinite effect
                                        ForEach(actionButtons, id: \.self) { action in
                                            Button(action: {
                                                promptText = action
                                                isFocused = true
                                                showActionCards = false
                                            }) {
                                                Text(action)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.appText)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(width: 220)
                                                    .frame(height: 50)
                                                    .background(Color.appCardBackground)
                                                    .cornerRadius(13)
                                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .frame(height: 100)
                                .padding(.bottom, 90)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        // Chat View
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(messages) { message in
                                        ChatMessageView(message: message)
                                    }
                                }
                                .padding()
                            }
                            .onChange(of: messages.count) { _, _ in
                                withAnimation {
                                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .offset(x: isSidebarShowing ? 280 : 0)
                .animation(.easeInOut(duration: 0.25), value: isSidebarShowing)
                
                // Bottom Bar and Attachment Menu Container
                if !showNotebook {
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Bottom Bar
                        HStack(spacing: 12) {
                            // Plus button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isAttachmentMenuShowing.toggle()
                                    if isAttachmentMenuShowing {
                                        isFocused = false
                                        showActionCards = false
                                    }
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.leading, 5)
                            
                            // Text input field
                            TextField("Message", text: $promptText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.appCardBackground)
                                .cornerRadius(20)
                                .frame(maxWidth: isTextFieldFocused ? .infinity : geometry.size.width * 0.6)
                                .foregroundColor(.appText)
                                .accentColor(.appAccent)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .focused($isFocused)
                                .onChange(of: isFocused) { oldValue, newValue in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isTextFieldFocused = newValue
                                    }
                                }
                                .submitLabel(.send)
                                .onSubmit {
                                    sendMessage()
                                }
                            
                            if !isTextFieldFocused {
                                // Camera button
                                Button(action: {
                                    // TODO: Implement camera functionality
                                }) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.appAccent)
                                }
                                
                                // Microphone button
                                Button(action: {
                                    // Microphone action
                                }) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.appAccent)
                                }
                            } else {
                                // Send button
                                Button(action: {
                                    sendMessage()
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                        .padding([.leading, .bottom, .trailing], 20)
                        .frame(height: 94)
                        .background(Color.appHeaderBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
                        
                        // Attachment Menu
                        if isAttachmentMenuShowing {
                            AttachmentMenuView(isShowing: $isAttachmentMenuShowing, selectedPhoto: $selectedPhoto)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .offset(y: isAttachmentMenuShowing ? -10 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAttachmentMenuShowing)
                }
                
                if isSidebarShowing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isSidebarShowing = false
                        }
                    
                    HStack {
                        SidebarView(isShowing: $isSidebarShowing)
                            .transition(.move(edge: .leading))
                        
                        Spacer()
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                // Top Bar
                if !showNotebook {
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                withAnimation {
                                    isSidebarShowing.toggle()
                                }
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 24))
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal, 34)
                            .padding(.vertical, 26)
                            
                            Spacer()
                            
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
                                    isAttachmentMenuShowing = false
                                }) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 24))
                                        .foregroundColor(.appAccent)
                                }
                                .padding(.horizontal, 34)
                                .padding(.vertical, 20)
                            }
                        }
                    }
                    .frame(height: 120)
                    .background(Color.appHeaderBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    private func sendMessage() {
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messages.append(ChatMessage(content: promptText, image: nil, isUser: true, timestamp: Date()))
        promptText = ""
        isFocused = false
        showActionCards = false
    }
    
    private func animateText() {
        var charIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if charIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: charIndex)
                animatedText += String(fullText[index])
                charIndex += 1
            } else {
                hasAnimatedText = true
                timer.invalidate()
            }
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250)
                        .cornerRadius(12)
                }
                
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.appAccent : Color.appCardBackground)
                        .foregroundColor(message.isUser ? .white : .appText)
                        .cornerRadius(16)
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            if !message.isUser {
                Spacer()
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
