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
    @State private var inputText: String = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.featureCalloutText)
            Text(title)
                .foregroundColor(.featureCalloutText)
            Spacer()
            if isEditing {
                TextField(title, text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color.featureCalloutButtonBackground)
                    .cornerRadius(8)
                    .frame(width: 200)
                    .onSubmit {
                        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else {
                            // Don't save and stay in editing mode
                            return
                        }
                        Task {
                            isLoading = true
                            text = inputText
                            await onSave()
                            isLoading = false
                            isEditing = false
                        }
                    }
            } else {
                HStack {
                    Text(text.isEmpty ? "Not set" : text)
                        .foregroundColor(text.isEmpty ? .featureCalloutText.opacity(0.6) : .featureCalloutText)
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .onTapGesture {
                    inputText = text
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
    @State private var profileImage: UIImage?
    @State private var isLoadingRecentNotes = true
    @State private var shimmerAnimation = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isProfileSheetPresented = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var isLoadingProfileImage = false
    @StateObject private var alertManager = AlertManager()
    @State private var isShowingNewNoteSheet = false
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var isShowingTopicSelection = false
    @State private var isShowingSubtopicSelection = false
    @State private var isShowingNoteDetails = false
    
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
                            .foregroundColor(.featureCalloutAccent)
                    }
                    VStack(alignment: .leading) {
                        Text("Profile")
                            .font(.headline)
                            .foregroundColor(.featureCalloutText)
                        Text("View your profile")
                            .font(.subheadline)
                            .foregroundColor(.featureCalloutText.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(.featureCalloutText.opacity(0.5))
                }
                .padding()
                .background(Color.featureCalloutBackground2)
            }
            .sheet(isPresented: $isProfileSheetPresented) {
                ProfileSheetView(isPresented: $isProfileSheetPresented, authManager: authManager)
            }
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 0) {
                    // Recent Notes Section
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("Recent Notes")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.featureCalloutText)
                            
                            Spacer()
                            
                            Button(action: {
                                isShowingTopicSelection = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.featureCalloutAccent)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                        
                        Group {
                            if isLoadingRecentNotes || recentNotes.isEmpty {
                            VStack(spacing: 0) {
                                // Ghost date group header
                                HStack {
                                    Rectangle()
                                        .fill(Color.featureCalloutText.opacity(0.4))
                                        .frame(width: 80, height: 14)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                
                                // Ghost note items
                                ForEach(0..<3, id: \.self) { index in
                                    HStack {
                                        Rectangle()
                                            .fill(Color.featureCalloutText.opacity(0.3))
                                            .frame(width: CGFloat.random(in: 120...200), height: 16)
                                            .cornerRadius(4)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .cornerRadius(8)
                                    .padding(.vertical, 12)
                                }
                            }
                            .opacity(shimmerAnimation ? 0.5 : 0.8)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: shimmerAnimation)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                                        .foregroundColor(.featureCalloutText.opacity(0.7))
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    
                                    ForEach(groupedNotes[dateGroup] ?? []) { note in
                                        recentNoteButton(note)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 1.05)))
                        } else {
                            Text("No recent notes")
                                .font(.subheadline)
                                .foregroundColor(.featureCalloutText.opacity(0.7))
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        }
                        .animation(.easeInOut(duration: 0.3), value: isLoadingRecentNotes)
                        .animation(.easeInOut(duration: 0.3), value: recentNotes.count)
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
                                window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                            }
                        }
                    }
                }) {
                    Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.featureCalloutAccent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 20)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .rotationEffect(.degrees(isDarkMode ? 180 : 0))
                }
            }
            .background(Color.featureCalloutBackground2)
        }
        .frame(width: 280)
        .background(Color.featureCalloutBackground2)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            // Start shimmer animation
            shimmerAnimation = true
            
            Task {
                await loadProfileImage()
                await loadRecentNotes()
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
                }
            }
        }
        .sheet(isPresented: $isShowingTopicSelection) {
            ZStack {
                // Animated gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.featureCalloutBackground,
                        Color.featureCalloutBackground2
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header with icon
                    VStack(spacing: 12) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.featureCalloutAccent)
                            .padding(.top, 40)
                        
                        Text("Create New Note")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.featureCalloutText)
                        
                        Text("Choose a topic to organize your thoughts")
                            .font(.subheadline)
                            .foregroundColor(.featureCalloutText.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    // Topics grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(dataManager.topics) { topic in
                                Button(action: {
                                    selectedTopic = topic
                                    isShowingTopicSelection = false
                                    isShowingSubtopicSelection = true
                                }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.featureCalloutAccent)
                                        
                                        Text(topic.title)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.featureCalloutText)
                                            .multilineTextAlignment(.center)
                                        
                                        Text("\(topic.subtopics.count) subtopics")
                                            .font(.caption)
                                            .foregroundColor(.featureCalloutText.opacity(0.6))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.featureCalloutBackground2)
                                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.featureCalloutBorder.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
                
                // Close button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingTopicSelection = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.featureCalloutText.opacity(0.6))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $isShowingSubtopicSelection) {
            if let topic = selectedTopic {
                ZStack {
                    // Animated gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.featureCalloutBackground,
                            Color.featureCalloutBackground2
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Header with icon
                        VStack(spacing: 12) {
                            Image(systemName: "folder.fill.badge.person.crop")
                                .font(.system(size: 40))
                                .foregroundColor(.featureCalloutAccent)
                                .padding(.top, 40)
                            
                            Text("Choose Subtopic")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.featureCalloutText)
                            
                            Text("Select a subtopic in '\(topic.title)'")
                                .font(.subheadline)
                                .foregroundColor(.featureCalloutText.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Subtopics grid
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(topic.subtopics) { subtopic in
                                    Button(action: {
                                        selectedSubtopic = subtopic
                                        isShowingSubtopicSelection = false
                                        isShowingNoteDetails = true
                                    }) {
                                        VStack(spacing: 12) {
                                            Image(systemName: "folder.fill.badge.person.crop")
                                                .font(.system(size: 24))
                                                .foregroundColor(.featureCalloutAccent)
                                            
                                            Text(subtopic.title)
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.featureCalloutText)
                                                .multilineTextAlignment(.center)
                                            
                                            Text("\(subtopic.notes.count) notes")
                                                .font(.caption)
                                                .foregroundColor(.featureCalloutText.opacity(0.6))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.featureCalloutBackground2)
                                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.featureCalloutBorder.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer()
                    }
                    
                    // Close button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isShowingSubtopicSelection = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.featureCalloutText.opacity(0.6))
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 20)
                        }
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingNoteDetails) {
            if let topic = selectedTopic, let subtopic = selectedSubtopic {
                ZStack {
                    // Animated gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.featureCalloutBackground,
                            Color.featureCalloutBackground2
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        // Header with icon
                        VStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .font(.system(size: 40))
                                .foregroundColor(.featureCalloutAccent)
                                .padding(.top, 40)
                            
                            Text("Create Your Note")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.featureCalloutText)
                            
                            Text("Add to '\(subtopic.title)' in '\(topic.title)'")
                                .font(.subheadline)
                                .foregroundColor(.featureCalloutText.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Note creation form
                        VStack(spacing: 20) {
                            // Title field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note Title")
                                    .font(.headline)
                                    .foregroundColor(.featureCalloutText)
                                    .padding(.horizontal, 20)
                                
                                TextField("Enter title...", text: $newNoteTitle)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.featureCalloutBackground2)
                                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.featureCalloutBorder.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(.horizontal, 20)
                            }
                            
                            // Content field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note Content")
                                    .font(.headline)
                                    .foregroundColor(.featureCalloutText)
                                    .padding(.horizontal, 20)
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.featureCalloutBackground2)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.featureCalloutBorder.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    ClearBackgroundTextEditor(text: $newNoteContent)
                                        .frame(minHeight: 120)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                isShowingNoteDetails = false
                                resetNoteCreation()
                            }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(.featureCalloutText.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.featureCalloutBackground2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.featureCalloutBorder.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Button(action: {
                                handleNoteCreation(topic: topic, subtopic: subtopic)
                            }) {
                                Text("Create Note")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(newNoteTitle.isEmpty ? Color.featureCalloutText.opacity(0.3) : Color.featureCalloutAccent)
                                    )
                            }
                            .disabled(newNoteTitle.isEmpty)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    
                    // Close button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                isShowingNoteDetails = false
                                resetNoteCreation()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.featureCalloutText.opacity(0.6))
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 20)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func loadRecentNotes() async {
        isLoadingRecentNotes = true
        
        // Ensure ghost blocks show for at least 0.5 seconds
        try? await Task.sleep(nanoseconds: 0_500_000_000)
        
        do {
            recentNotes = try await dataManager.getRecentNotes()
        } catch {
            await MainActor.run {
                alertManager.showError(AppError.dataError("Failed to load recent notes"))
            }
        }
        
        isLoadingRecentNotes = false
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
                    .foregroundColor(.featureCalloutText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.featureCalloutBackground2)
            .cornerRadius(8)
        }
    }
    
    private func resetNoteCreation() {
        newNoteTitle = ""
        newNoteContent = ""
        selectedTopic = nil
        selectedSubtopic = nil
    }
    
    private func handleNoteCreation(topic: Topic, subtopic: Subtopic) {
        Task {
            do {
                // Create a new note using addNote
                let newNote = try await dataManager.addNote(
                    to: subtopic,
                    in: topic,
                    title: newNoteTitle,
                    content: newNoteContent
                )
                
                // Add to recent notes
                try await dataManager.addRecentNote(noteId: newNote.id.uuidString)
                
                // Update UI but don't show the note
                await MainActor.run {
                    noteDisplayState.currentNote = newNote
                    noteDisplayState.currentTopic = topic
                    noteDisplayState.currentSubtopic = subtopic
                    isShowing = false
                    isShowingNoteDetails = false
                    resetNoteCreation()
                    
                    // Play completion sound
                    print("🎵 About to play completion sound for note creation")
                    SoundManager.shared.playCompletionSound()
                }
            } catch {
                print("❌ Failed to create note: \(error.localizedDescription)")
                await MainActor.run {
                    alertManager.showError(AppError.dataError("Failed to create note: \(error.localizedDescription)"))
                }
            }
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
    @StateObject private var alertManager = AlertManager()
    
    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                mainView
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
                }
            }
        } message: {
            VStack {
                Text(alertManager.alertMessage)
                if !alertManager.alertRecoverySuggestion.isEmpty {
                    Text(alertManager.alertRecoverySuggestion)
                        .font(.caption)
                        .foregroundColor(.featureCalloutText.opacity(0.7))
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
            // Handle deep link for password reset and OAuth
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
                } else if url.host == "camera" {
                    print("✅ Valid camera URL detected")
                    // Camera handling is done in ScriboApp.swift
                } else {
                    print("❌ Invalid URL host: \(url.host ?? "nil")")
                }
            } else if url.absoluteString.contains("supabase.co/auth/v1/callback") {
                print("✅ Valid Supabase callback URL detected")
                Task {
                    await authManager.checkSession()
                }
            } else {
                print("❌ Invalid URL scheme: \(url.scheme ?? "nil")")
            }
        }
    }
    
    private var mainView: some View {
        GeometryReader { geometry in
            ZStack {
                Color.featureCalloutBackground
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
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                DocumentManagerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotebook)
        .animation(.easeInOut(duration: 0.2), value: noteDisplayState.isShowingNote)
    }
    
    private var sidebarOverlay: some View {
        Group {
            if isSidebarShowing {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.6)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
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
            .background(Color.clear)
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
                .foregroundColor(.featureCalloutAccent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var navigationButton: some View {
        Group {
            Button(action: {
                showNotebook = true
            }) {
                Image(systemName: "note.text")
                    .font(.system(size: 20))
                    .foregroundColor(.featureCalloutAccent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical,16)
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
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var email = ""
    @StateObject private var alertManager = AlertManager()
    @State private var showingAvatarPicker = false
    @StateObject private var notificationManager = NotificationManager.shared
    
    let defaultAvatars = [
        "avatar1", "avatar2", "avatar3",
        "avatar4", "avatar5", "avatar6"
    ]
    
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
                                .overlay(Circle().stroke(Color.featureCalloutAccent, lineWidth: 2))
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.featureCalloutText.opacity(0.5))
                                .overlay(Circle().stroke(Color.featureCalloutAccent, lineWidth: 2))
                        }
                        Button(action: {
                            showingAvatarPicker = true
                        }) {
                            Text("Change Avatar")
                                .font(.subheadline)
                                .foregroundColor(.featureCalloutAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                // Account Info Section
                Section(header: Text("Account").foregroundColor(.featureCalloutText)) {
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
                
                Section(header: Text("Preferences").foregroundColor(.featureCalloutText)) {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("English").tag("English")
                        Text("Spanish").tag("Spanish")
                    }
                    .foregroundColor(.featureCalloutText)
                    
                    HStack {
                        Image(systemName: "moon")
                            .foregroundColor(.featureCalloutText)
                        Text("Dark Mode")
                            .foregroundColor(.featureCalloutText)
                        Spacer()
                        Toggle("", isOn: $isDarkMode)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .foregroundColor(.featureCalloutText)
                        Text("Haptic Feedback")
                            .foregroundColor(.featureCalloutText)
                        Spacer()
                        Toggle("", isOn: $hapticsEnabled)
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("Notifications & Sounds").foregroundColor(.featureCalloutText)) {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { notificationManager.isAuthorized },
                        set: { _ in notificationManager.toggleNotifications() }
                    ))
                    .onChange(of: notificationManager.isAuthorized) { oldValue, newValue in
                        if newValue {
                            notificationManager.requestAuthorization()
                        }
                    }
                    
                    Toggle("Sound Effects", isOn: Binding(
                        get: { notificationManager.soundEffectsEnabled },
                        set: { _ in notificationManager.toggleSoundEffects() }
                    ))
                    .foregroundColor(.featureCalloutText)
                }
                
                Section(header: Text("Suggestions").foregroundColor(.featureCalloutText)) {
                    NavigationLink(destination: FeedbackView()) {
                        Label("Submit Feedback", systemImage: "paperplane")
                            .foregroundColor(.featureCalloutText)
                    }
                }
                
                Section(header: Text("About").foregroundColor(.featureCalloutText)) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.featureCalloutText)
                        Text("Version")
                            .foregroundColor(.featureCalloutText)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.featureCalloutText.opacity(0.7))
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.featureCalloutText)
                        Text("Privacy Policy")
                            .foregroundColor(.featureCalloutText)
                        Spacer()
                        Link("View", destination: URL(string: "https://yourapp.com/privacy")!)
                            .foregroundColor(.featureCalloutAccent)
                    }
                    
                    NavigationLink(destination: LicenseView()) {
                        HStack {
                            Image(systemName: "doc.plaintext")
                                .foregroundColor(.featureCalloutText)
                            Text("Licenses")
                                .foregroundColor(.featureCalloutText)
                        }
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
                                .foregroundColor(.featureCalloutText.opacity(0.7))
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
                            .foregroundColor(.featureCalloutText.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerView(selectedAvatar: $avatarImage, isPresented: $showingAvatarPicker) { selectedImage in
                Task {
                        await saveProfile()
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
                            .foregroundColor(.featureCalloutText.opacity(0.7))
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

struct AvatarPickerView: View {
    @Binding var selectedAvatar: UIImage?
    @Binding var isPresented: Bool
    let onSelect: (UIImage) -> Void
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    let defaultAvatars = [
        "avatar1", "avatar2", "avatar3",
        "avatar4", "avatar5", "avatar6"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(defaultAvatars, id: \.self) { avatarName in
                        Button(action: {
                            if let image = UIImage(named: avatarName) {
                                selectedAvatar = image
                                onSelect(image)
                                isPresented = false
                            }
                        }) {
                            Image(avatarName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.featureCalloutAccent, lineWidth: 2))
                                .shadow(color: Color.featureCalloutBorder.opacity(0.2), radius: 4)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.featureCalloutAccent)
                }
            }
        }
    }
}

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("IMPORTANT NOTICE")
                    .font(.headline)
                    .foregroundColor(.featureCalloutAccent)
                
                Text("This license only applies if you downloaded this vector as an unsubscribed user. If you are a premium user (ie, you pay a subscription) you are bound to the license terms described in the accompanying file \"License premium.txt\".")
                    .foregroundColor(.featureCalloutText)
                    .padding(.bottom)
                
                Text("Attribution Requirements")
                    .font(.headline)
                    .foregroundColor(.featureCalloutText)
                
                Text("You must attribute the image to its author:")
                    .font(.subheadline)
                    .foregroundColor(.featureCalloutText)
                
                Text("In order to use a vector or a part of it, you must attribute it to Freepik, so we will be able to continue creating new graphic resources every day.")
                    .foregroundColor(.featureCalloutText)
                    .padding(.bottom)
                
                Text("How to attribute it?")
                    .font(.headline)
                
                Group {
                    Text("For websites:")
                        .font(.subheadline)
                    Text("Please, copy this code on your website to accredit the author:")
                    Text("<a href=\"http://www.freepik.com\">Designed by Freepik</a>")
                        .font(.system(.body, design: .monospaced))
                        .padding(.bottom)
                    
                    Text("For printing:")
                        .font(.subheadline)
                    Text("Paste this text on the final work so the authorship is known.")
                    Text("For example, in the acknowledgements chapter of a book:")
                    Text("\"Designed by Freepik\"")
                        .italic()
                        .padding(.bottom)
                }
                
                Text("Usage Rights")
                    .font(.headline)
                
                Text("You are free to use this image:")
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• For both personal and commercial projects and to modify it.")
                    Text("• In a website or presentation template or application or as part of your design.")
                }
                .padding(.bottom)
                
                Text("Restrictions")
                    .font(.headline)
                
                Text("You are not allowed to:")
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• Sub-license, resell or rent it.")
                    Text("• Include it in any online or offline archive or database.")
                }
                .padding(.bottom)
                
                Text("Full Terms")
                    .font(.headline)
                
                Text("The full terms of the license are described in section 7 of the Freepik terms of use, available online in the following link:")
                
                Link("http://www.freepik.com/terms_of_use", destination: URL(string: "http://www.freepik.com/terms_of_use")!)
                    .foregroundColor(.featureCalloutAccent)
                    .padding(.bottom)
                
                Text("The terms described in the above link have precedence over the terms described in the present document. In case of disagreement, the Freepik Terms of Use will prevail.")
            }
            .padding()
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}
