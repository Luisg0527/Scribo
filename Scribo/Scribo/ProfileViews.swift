import SwiftUI
// MARK: - Editable Field

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


// MARK: - Profile Sheet View

struct ProfileSheetView: View {
    @Binding var isPresented: Bool
    @ObservedObject var authManager: AuthManager
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var hapticsEnabled = true
    @State private var selectedLanguage = "English"
    @State private var selectedVoice = "Default"
    @State private var speechSpeed: Double = 1.0
    @State private var feedbackText = ""
    @StateObject private var dataManager = DataManager.shared
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
                        Image(systemName: "xmark")
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
    
    // MARK: - Avatar Picker View
    
    
    struct AvatarPickerView: View {
        @Binding var selectedAvatar: UIImage?
        @Binding var isPresented: Bool
        let onSelect: (UIImage) -> Void
        
        private let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
        
        private let defaultAvatars = [
            "avatar1", "avatar2", "avatar3",
            "avatar4", "avatar5", "avatar6"
        ]
        
        var body: some View {
            VStack(spacing: 0) {
                // Header: title + close button (App Icon–style)
                HStack {
                    Text("Profile Icon")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(.secondaryLabel))
                            .frame(width: 28, height: 28)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
                .padding(.bottom, 26)
                
                // Icon grid (scrollable so it always fits)
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
                                avatarTile(avatarName: avatarName)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .presentationDetents([.medium])
            .presentationCornerRadius(40)
        }
        
        private func avatarTile(avatarName: String) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4).opacity(0.8), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
                
                Image(avatarName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        }
    }
}

// MARK: - License View

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
