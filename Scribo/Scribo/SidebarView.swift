import SwiftUI
import PhotosUI

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var isShowing: Bool
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showProfile = false
    @EnvironmentObject var noteDisplayState: NoteDisplayState
    @State private var recentNotes: [Note] = []
    @ObservedObject var authManager: AuthManager
    @StateObject private var dataManager = DataManager.shared
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
                            Image(systemName: "xmark")
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
                                Image(systemName: "xmark")
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
                                Image(systemName: "xmark")
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