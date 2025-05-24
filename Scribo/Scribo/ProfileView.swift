import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var dataManager = DataManager()
    @State private var fullName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Image Section
                    VStack(spacing: 16) {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.appAccent1, lineWidth: 2)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 10)
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                .frame(width: 120, height: 120)
                                    .foregroundColor(.gray)
                                .overlay(
                                    Circle()
                                        .stroke(Color.appAccent1, lineWidth: 2)
                                )
                            }
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text("Change Photo")
                                .font(.subheadline)
                                .foregroundColor(.appAccent1)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Profile Information Section
                    VStack(spacing: 16) {
                    TextField("Full Name", text: $fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                }
                    .padding(.horizontal)
                
                    // Action Buttons
                    VStack(spacing: 16) {
                    Button(action: saveProfile) {
                            HStack {
                        if isLoading {
                            ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save Changes")
                        }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent1)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                        .disabled(isLoading || fullName.isEmpty)
                }
                    .padding(.horizontal)
                    
                    // Sign Out Button
                    Button(action: {
                        Task {
                            await authManager.signOut()
                        }
                    }) {
                        Text("Sign Out")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appCardBackground)
                            .foregroundColor(.appText)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        avatarImage = image
                    }
                }
            }
            .task {
                await loadProfile()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func loadProfile() async {
        do {
            let user = try await dataManager.getUserProfile()
            fullName = user.full_name
            
            if let avatarUrl = user.avatar_url {
                let fileURL = dataManager.getDocumentsDirectory().appendingPathComponent(avatarUrl)
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    avatarImage = image
                }
            }
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }
    
    private func saveProfile() {
        Task {
            isLoading = true
            do {
                try await dataManager.updateUserProfile(fullName: fullName, avatarImage: avatarImage)
            } catch {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
} 