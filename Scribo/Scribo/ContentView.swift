import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import VisionKit
import StoreKit

// MARK: - Note Display State
class NoteDisplayState: ObservableObject {
    @Published var isShowingNote: Bool = false
    @Published var currentNote: Note?
    @Published var currentTopic: Topic?
    @Published var currentSubtopic: Subtopic?
}

// Add this near the top of the file, after the imports
enum AppError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case dataError(String)
    case cameraError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .dataError(let message):
            return "Data Error: \(message)"
        case .cameraError(let message):
            return "Camera Error: \(message)"
        case .unknownError(let message):
            return "Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .authenticationError:
            return "Please try logging in again."
        case .dataError:
            return "Please try refreshing the data."
        case .cameraError:
            return "Please check camera permissions in Settings."
        case .unknownError:
            return "Please try again later."
        }
    }
}

// Add this class for managing alerts
class AlertManager: ObservableObject {
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var alertRecoverySuggestion = ""
    
    func showError(_ error: Error) {
        if let appError = error as? AppError {
            alertTitle = "Error"
            alertMessage = appError.errorDescription ?? "An error occurred"
            alertRecoverySuggestion = appError.recoverySuggestion ?? "Please try again later."
        } else {
            alertTitle = "Error"
            alertMessage = error.localizedDescription
            alertRecoverySuggestion = "Please try again later."
        }
        showAlert = true
    }
}

// Add this struct before ProfileSheetView
struct EditableField: View {
    let icon: String
    let title: String
    @Binding var text: String
    @State private var isEditing = false
    let onSave: () async -> Void
    @State private var isLoading = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            if isEditing {
                TextField(title, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(width: 200)
                    .onSubmit {
                        Task {
                            isLoading = true
                            await onSave()
                            isLoading = false
                            isEditing = false
                        }
                    }
            } else {
                HStack {
                    Text(text)
                        .foregroundColor(.gray)
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .onTapGesture {
                    isEditing = true
                }
            }
        }
    }
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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProfileSheetPresented = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var isLoadingProfileImage = false
    @StateObject private var alertManager = AlertManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile Section
            Button(action: {
                performHapticFeedback(style: .light)
                isProfileSheetPresented = true
            }) {
                HStack {
                    if isLoadingProfileImage {
                        ProgressView()
                            .frame(width: 40, height: 40)
                    } else if let profileImage {
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
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.appHeaderBackground)
            }
            .sheet(isPresented: $isProfileSheetPresented) {
                ProfileSheetView(isPresented: $isProfileSheetPresented, authManager: authManager)
            }
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 0) {
                    // Other Tools Section
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            presentDocumentScanner()
                        }) {
                            HStack {
                                Image(systemName: "doc.viewfinder")
                                    .foregroundColor(.appAccent1)
                                Text("Scanner")
                                    .foregroundColor(.appText)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .padding(.top, 16)
                        }
                    }
                    .background(Color.appCardBackground)
                    
                    // Recent Notes Section
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                        Text("Recent Notes")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.appText)
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    do {
                                        let alert = createNewNoteAlert()
                                        presentAlert(alert)
                                    }
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.appAccent1)
                            }
                        }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        
                        if showGhostBlocks {
                            ForEach(0..<3) { _ in
                                HStack {
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
                            let groupedNotes = Dictionary(grouping: recentNotes) { note in
                                let calendar = Calendar.current
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                                
                                guard let date = dateFormatter.date(from: note.updated_at) else {
                                    return "Older"
                                }
                                
                                if calendar.isDateInToday(date) {
                                    return "Today"
                                } else if calendar.isDateInYesterday(date) {
                                    return "Yesterday"
                                } else {
                                    let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
                                    if days < 7 {
                                        return "\(days) days ago"
                                    } else {
                                        let weeks = days / 7
                                        return "\(weeks) week\(weeks > 1 ? "s" : "") ago"
                                    }
                                }
                            }
                            
                            // Sort date groups in reverse chronological order
                            let sortedDateGroups = groupedNotes.keys.sorted { group1, group2 in
                                let order = ["Today", "Yesterday", "1 day ago", "2 days ago", "3 days ago", "4 days ago", "5 days ago", "6 days ago", "1 week ago", "2 weeks ago", "3 weeks ago", "4 weeks ago", "Older"]
                                let index1 = order.firstIndex(of: group1) ?? Int.max
                                let index2 = order.firstIndex(of: group2) ?? Int.max
                                return index1 < index2
                            }
                            
                            ForEach(sortedDateGroups, id: \.self) { dateGroup in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(dateGroup)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    
                                    ForEach(groupedNotes[dateGroup] ?? []) { note in
                                        recentNoteButton(note)
                                    }
                                }
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
                                .font(.title3)
                                .fontWeight(.semibold)
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
                            let groupedChats = Dictionary(grouping: chats.sorted(by: { $0.updatedAt > $1.updatedAt })) { chat in
                                let calendar = Calendar.current
                                if calendar.isDateInToday(chat.updatedAt) {
                                    return "Today"
                                } else if calendar.isDateInYesterday(chat.updatedAt) {
                                    return "Yesterday"
                                } else {
                                    let days = calendar.dateComponents([.day], from: chat.updatedAt, to: Date()).day ?? 0
                                    if days < 7 {
                                        return "\(days) days ago"
                                    } else {
                                        let weeks = days / 7
                                        return "\(weeks) week\(weeks > 1 ? "s" : "") ago"
                                    }
                                }
                            }
                            
                            ForEach(groupedChats.keys.sorted(), id: \.self) { dateGroup in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(dateGroup)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    
                                    ForEach(groupedChats[dateGroup] ?? []) { chat in
                                        Button(action: {
                                            currentChat = chat
                                        }) {
                                            HStack {
                                                Text(chat.title)
                                                    .foregroundColor(.appText)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                Spacer()
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 12)
                                        }
                                        .contextMenu {
                                            Button(action: {
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
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            
                                            Button(action: {
                                                Task {
                                                    do {
                                                        // Create a temporary alert to get new title
                                                        let alert = UIAlertController(
                                                            title: "Edit Chat Title",
                                                            message: "Enter new title for the chat",
                                                            preferredStyle: .alert
                                                        )
                                                        
                                                        alert.addTextField { textField in
                                                            textField.text = chat.title
                                                            textField.placeholder = "Enter title"
                                                        }
                                                        
                                                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                                        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                                                            if let newTitle = alert.textFields?.first?.text, !newTitle.isEmpty {
                                                                Task {
                                                                    do {
                                                                        var updatedChat = chat
                                                                        updatedChat.title = newTitle
                                                                        try await chatManager.updateChat(updatedChat)
                                                                        await MainActor.run {
                                                                            if let index = chats.firstIndex(where: { $0.id == chat.id }) {
                                                                                chats[index] = updatedChat
                                                                            }
                                                                            if currentChat?.id == chat.id {
                                                                                currentChat = updatedChat
                                                                            }
                                                                        }
                                                                    } catch {
                                                                        print("❌ Failed to update chat title: \(error.localizedDescription)")
                                                                    }
                                                                }
                                                            }
                                                        })
                                                        
                                                        // Present the alert
                                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                           let viewController = windowScene.windows.first?.rootViewController {
                                                            viewController.present(alert, animated: true)
                                                        }
                                                    }
                                                }
                                            }) {
                                                Label("Edit Title", systemImage: "pencil")
                                            }
                                        }
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
                // Dark Mode Toggle
                Button(action: {
                    performHapticFeedback(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDarkMode.toggle()
                        // Force UI update
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            windowScene.windows.forEach { window in
                                window.overrideUserInterfaceStyle = isDarkMode ? .light : .dark
                            }
                        }
                    }
                }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appAccent1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 20)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .rotationEffect(.degrees(isDarkMode ? 180 : 0))
                }
            }
            .background(Color.appCardBackground.opacity(0.8))
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
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load recent notes"))
            }
        }
        
        isLoadingRecentNotes = false
        showGhostBlocks = false
    }
    
    private func loadProfileImage() async {
        isLoadingProfileImage = true
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
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load profile image"))
            }
        }
        isLoadingProfileImage = false
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
                    }
                } catch {
                    await MainActor.run {
                        alertManager.showError(AppError.dataError("Failed to create welcome chat"))
                    }
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
            await MainActor.run {
                alertManager.showError(AppError.networkError("Failed to load chats"))
            }
        }
        isLoadingChats = false
        print("📱 Finished loading chats")
    }
    
    private func performHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
    
    private func recentNoteButton(_ note: Note) -> some View {
        Button(action: {
            performHapticFeedback(style: .medium)
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
                Text(note.title)
                    .foregroundColor(.appText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    private func presentDocumentScanner() {
        print("📱 Starting document scanner...")
        let scannerVC = VNDocumentCameraViewController()
        let delegate = DocumentScannerDelegate(
            onScanComplete: { scannedImage in
                print("📱 Document scanner completed, received image of size: \(scannedImage.size)")
                
                                    // Create a new chat with the scanned document
                                    Task {
                                        do {
                        print("📱 Creating new chat for scanned document...")
                                            let dateFormatter = DateFormatter()
                                            dateFormatter.dateFormat = "MMM d, h:mm a"
                                            let timestamp = dateFormatter.string(from: Date())
                                            let newChat = try await chatManager.createChat(title: "Scanned Document \(timestamp)")
                        print("📱 Successfully created new chat with ID: \(newChat.id)")
                        
                        // Convert image to PDF
                        print("📱 Converting scanned image to PDF...")
                        let pdfData = try await convertImageToPDF(scannedImage)
                        print("📱 PDF created with size: \(pdfData.count) bytes")
                        
                        // Save PDF to temporary file
                        let tempDir = FileManager.default.temporaryDirectory
                        let pdfFileName = "scanned_document_\(UUID().uuidString).pdf"
                        let pdfURL = tempDir.appendingPathComponent(pdfFileName)
                        try pdfData.write(to: pdfURL)
                        print("📱 PDF saved to temporary file: \(pdfURL.path)")
                        
                        // Create document message
                        print("📱 Creating chat message with PDF document...")
                        let message = ChatMessage(
                            content: "I've scanned this document for you.",
                            image: nil,
                            document: DocumentMessage(
                                url: pdfURL,
                                name: "Scanned Document \(timestamp).pdf",
                                type: "pdf"
                            ),
                            isUser: true,
                            timestamp: Date(),
                            chatId: newChat.id
                        )
                        
                        // Add the message to the chat
                        print("📱 Adding message to chat...")
                        try await chatManager.addMessage(message, to: newChat.id)
                        print("📱 Successfully added message to chat")
                        
                        // Update the UI
                        print("📱 Updating UI with new chat...")
                                            await MainActor.run {
                                                chats.append(newChat)
                                                currentChat = newChat
                            print("📱 UI updated with new chat")
                                            }
                                        } catch {
                        print("❌ Failed to process scanned document: \(error.localizedDescription)")
                        await MainActor.run {
                            alertManager.showError(AppError.dataError("Failed to process scanned document: \(error.localizedDescription)"))
                        }
                    }
                }
            },
            onError: { error in
                print("❌ Document scanner error: \(error.localizedDescription)")
                Task { @MainActor in
                alertManager.showError(error)
                }
            }
        )
        scannerVC.delegate = delegate
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            print("📱 Presenting document scanner...")
            viewController.present(scannerVC, animated: true) {
                print("📱 Document scanner presented")
            }
        } else {
            print("❌ Failed to present document scanner - no window scene or view controller found")
        }
    }
    
    private func convertImageToPDF(_ image: UIImage) async throws -> Data {
        print("📱 Starting PDF conversion...")
        let pdfData = NSMutableData()
        
        // Create PDF context
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: image.size), nil)
        UIGraphicsBeginPDFPage()
        
        // Draw image
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        // End PDF context
        UIGraphicsEndPDFContext()
        
        print("📱 PDF conversion completed")
        return pdfData as Data
    }
    
    private func createNewNoteAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: "New Note",
            message: "Select topic and subtopic",
            preferredStyle: .actionSheet
        )
        
        // Add topic selection actions
        for topic in dataManager.topics {
            let topicAction = UIAlertAction(title: topic.title, style: .default) { _ in
                self.showSubtopicSelection(for: topic)
            }
            alert.addAction(topicAction)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }
    
    private func showSubtopicSelection(for topic: Topic) {
        let alert = UIAlertController(
            title: "Select Subtopic",
            message: "Choose a subtopic for your note",
            preferredStyle: .actionSheet
        )
        
        // Add subtopic selection actions
        for subtopic in topic.subtopics {
            let subtopicAction = UIAlertAction(title: subtopic.title, style: .default) { _ in
                self.showNoteDetailsInput(topic: topic, subtopic: subtopic)
            }
            alert.addAction(subtopicAction)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
    
    private func showNoteDetailsInput(topic: Topic, subtopic: Subtopic) {
        let alert = UIAlertController(
            title: "New Note",
            message: "Enter note details",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Title"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Content"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            self.handleNoteCreation(alert, topic: topic, subtopic: subtopic)
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
    
    private func handleNoteCreation(_ alert: UIAlertController, topic: Topic, subtopic: Subtopic) {
        guard let title = alert.textFields?[0].text,
              let content = alert.textFields?[1].text,
              !title.isEmpty else { return }
        
        Task {
            do {
                // Create a new note using addNote
                let newNote = try await dataManager.addNote(
                    to: subtopic,
                    in: topic,
                    title: title,
                    content: content
                )
                
                // Add to recent notes
                try await dataManager.addRecentNote(noteId: newNote.id.uuidString)
                
                // Update UI and show the note
                await MainActor.run {
                    noteDisplayState.currentNote = newNote
                    noteDisplayState.currentTopic = topic
                    noteDisplayState.currentSubtopic = subtopic
                    noteDisplayState.isShowingNote = true
                    isShowing = false
                }
            } catch {
                print("❌ Failed to create note: \(error.localizedDescription)")
                await MainActor.run {
                    alertManager.showError(AppError.dataError("Failed to create note: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func presentAlert(_ alert: UIAlertController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
}

// Add this class at the bottom of the file, before the last closing brace
class DocumentScannerDelegate: NSObject, VNDocumentCameraViewControllerDelegate {
    private let onScanComplete: (UIImage) -> Void
    private let onError: (Error) -> Void
    
    init(onScanComplete: @escaping (UIImage) -> Void, onError: @escaping (Error) -> Void) {
        print("📱 Initializing DocumentScannerDelegate")
        self.onScanComplete = onScanComplete
        self.onError = onError
        super.init()
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        print("📱 Document scanner didFinishWith scan, page count: \(scan.pageCount)")
        
        // Process each scanned page
        for i in 0..<scan.pageCount {
            print("📱 Processing page \(i + 1) of \(scan.pageCount)")
            let scannedImage = scan.imageOfPage(at: i)
            print("📱 Page \(i + 1) image size: \(scannedImage.size)")
            
            // Ensure we're on the main thread for UI updates
                DispatchQueue.main.async {
                self.onScanComplete(scannedImage)
                                                                }
                                                            }
        
        print("📱 Dismissing scanner view controller")
        controller.dismiss(animated: true) {
            print("📱 Scanner view controller dismissed")
            }
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print("❌ Document scanner failed with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
            self.onError(AppError.cameraError(error.localizedDescription))
            }
        controller.dismiss(animated: true) {
            print("📱 Scanner view controller dismissed after error")
                        }
                    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        print("📱 Document scanner was cancelled by user")
        controller.dismiss(animated: true) {
            print("📱 Scanner view controller dismissed after cancel")
        }
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
    @StateObject private var alertManager = AlertManager()
    
    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                mainView
                    .onAppear {
                        Task {
                            await loadChats()
                        }
                    }
            }
            
            if !authManager.isAuthenticated {
                if authManager.isResettingPassword {
                    NewPasswordView(authManager: authManager)
                        .transition(.move(edge: .top))
                } else {
                    LoginMethodView(authManager: authManager)
                        .transition(.move(edge: .top))
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: authManager.isResettingPassword)
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            if !newValue {
                isSidebarShowing = false
            }
        }
        .alert(alertManager.alertTitle, isPresented: $alertManager.showAlert) {
            Button("OK", role: .cancel) { }
            if !alertManager.alertRecoverySuggestion.isEmpty {
                Button("Try Again") {
                    // Retry the last operation
                    Task {
                        await loadChats()
                    }
                }
            }
        } message: {
            VStack {
                Text(alertManager.alertMessage)
                if !alertManager.alertRecoverySuggestion.isEmpty {
                    Text(alertManager.alertRecoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil {
                NavigationView {
                    NoteView(note: noteDisplayState.currentNote, isPresented: $showNotebook, dataManager: dataManager)
                        .navigationBarItems(leading: Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                noteDisplayState.isShowingNote = false
                                noteDisplayState.currentNote = nil
                                noteDisplayState.currentTopic = nil
                                noteDisplayState.currentSubtopic = nil
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                        })
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                ChatView(chats: $chats, currentChat: $currentChat)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showNotebook)
        .animation(.easeInOut(duration: 0.3), value: noteDisplayState.isShowingNote)
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
                do {
                    let welcomeChat = try await chatManager.createChat(title: "Welcome")
                    await MainActor.run {
                        chats = [welcomeChat]
                        currentChat = welcomeChat
                    }
                } catch {
                    await MainActor.run {
                        alertManager.showError(AppError.dataError("Failed to create welcome chat"))
                    }
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
            await MainActor.run {
                alertManager.showError(AppError.networkError("Failed to load chats"))
            }
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

struct ProfileSheetView: View {
    @Binding var isPresented: Bool
    @ObservedObject var authManager: AuthManager
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var hapticsEnabled = true
    @State private var selectedLanguage = "English"
    @State private var selectedVoice = "Default"
    @State private var speechSpeed: Double = 1.0
    @State private var feedbackText = ""
    @StateObject private var dataManager = DataManager()
    @State private var fullName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var email = ""
    @StateObject private var alertManager = AlertManager()
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Image Section
                Section {
                    VStack(spacing: 16) {
                        if let avatarImage {
                            Image(uiImage: avatarImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.appAccent1, lineWidth: 2))
                                .shadow(color: Color.black.opacity(0.1), radius: 8)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                                .overlay(Circle().stroke(Color.appAccent1, lineWidth: 2))
                        }
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text("Change Photo")
                                .font(.subheadline)
                                .foregroundColor(.appAccent1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                // Account Info Section
                Section(header: Text("Account")) {
                    EditableField(
                        icon: "person",
                        title: "Full Name",
                        text: $fullName,
                        onSave: saveProfile
                    )
                    EditableField(
                        icon: "envelope",
                        title: "Email",
                        text: $email,
                        onSave: saveEmail
                    )
                }
                
                Section(header: Text("Preferences")) {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("English").tag("English")
                        Text("Spanish").tag("Spanish")
                    }
                    HStack {
                        Image(systemName: "moon")
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: $isDarkMode)
                            .labelsHidden()
                    }
                    HStack {
                        Image(systemName: "iphone.gen3")
                        Text("Haptic Feedback")
                        Spacer()
                        Toggle("", isOn: $hapticsEnabled)
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("Suggestions")) {
                    TextField("Your feedback or feature request", text: $feedbackText)
                    Button(action: {
                        // Handle feedback submission
                    }) {
                        Label("Submit Feedback", systemImage: "paperplane")
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Privacy Policy")
                        Spacer()
                        Link("View", destination: URL(string: "https://yourapp.com/privacy")!)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            await authManager.signOut()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            avatarImage = image
                        }
                    }
                }
            }
            .task {
                await loadProfile()
            }
            .alert(alertManager.alertTitle, isPresented: $alertManager.showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                VStack {
                    Text(alertManager.alertMessage)
                    if !alertManager.alertRecoverySuggestion.isEmpty {
                        Text(alertManager.alertRecoverySuggestion)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        do {
            let user = try await dataManager.getUserProfile()
            let userEmail = try await dataManager.getUserEmail()
            await MainActor.run {
                fullName = user.full_name
                email = userEmail
                
                if let avatarUrl = user.avatar_url {
                    let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(avatarUrl)
                    if let data = try? Data(contentsOf: fileURL),
                       let image = UIImage(data: data) {
                        avatarImage = image
                    }
                }
            }
        } catch {
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load profile: \(error.localizedDescription)"))
            }
        }
        isLoading = false
    }
    
    private func saveProfile() async {
        isLoading = true
        do {
            try await dataManager.updateUserProfile(fullName: fullName, avatarImage: avatarImage)
            await MainActor.run {
                isPresented = false
            }
        } catch {
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to save profile: \(error.localizedDescription)"))
            }
        }
        isLoading = false
    }
    
    private func saveEmail() async {
        do {
            // First verify the new email is different from current
            let currentEmail = try await dataManager.getUserEmail()
            if currentEmail == email {
                return
            }
            
            // Update email through Supabase auth
            try await dataManager.updateUserEmail(email)
            
            // Show success message
            await MainActor.run {
                alertManager.alertTitle = "Success"
                alertManager.alertMessage = "Email updated successfully. Please check your new email for verification."
                alertManager.alertRecoverySuggestion = ""
                alertManager.showAlert = true
            }
        } catch {
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to update email: \(error.localizedDescription)"))
            }
        }
    }
}
