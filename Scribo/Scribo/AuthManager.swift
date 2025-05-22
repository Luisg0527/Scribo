import Foundation
import SwiftUI
import Supabase

// Temporary struct for user data insertion
private struct UserInsertData: Encodable {
    let id: String
    let full_name: String
    let avatar_url: String?
    let created_at: String
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var error: String?
    
    private let supabase = SupabaseConfig.shared.client
    
    init() {
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    @MainActor
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            
            // Get user profile from users table
            let response = try await supabase
                .from("users")
                .select()
                .eq("id", value: session.user.id)
                .single()
                .execute()
            
            let decoder = JSONDecoder()
            currentUser = try decoder.decode(User.self, from: response.data)
        } catch {
            isAuthenticated = false
            currentUser = nil
            self.error = error.localizedDescription
        }
    }
    
    @MainActor
    func signIn(email: String, password: String) async {
        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            isAuthenticated = true
            
            // Get user profile from users table
            let userResponse = try await supabase
                .from("users")
                .select()
                .eq("id", value: response.user.id)
                .single()
                .execute()
            
            let decoder = JSONDecoder()
            currentUser = try decoder.decode(User.self, from: userResponse.data)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    @MainActor
    func signUp(email: String, password: String) async {
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            isAuthenticated = true
            
            // Create user profile in users table
            let now = ISO8601DateFormatter().string(from: Date())
            let userData = UserInsertData(
                id: response.user.id.uuidString,
                full_name: "",
                avatar_url: nil,
                created_at: now
            )
            
            try await supabase
                .from("users")
                .insert(userData)
                .execute()
            
            // Fetch the created user profile
            let userResponse = try await supabase
                .from("users")
                .select()
                .eq("id", value: response.user.id)
                .single()
                .execute()
            
            let decoder = JSONDecoder()
            currentUser = try decoder.decode(User.self, from: userResponse.data)
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    @MainActor
    func signOut() async {
        do {
            // First check if we have a session
            if let session = try? await supabase.auth.session {
                try await supabase.auth.signOut()
            }
            
            // Clear local state
            isAuthenticated = false
            currentUser = nil
            self.error = nil
            
            // Verify session is cleared
            _ = try? await supabase.auth.session
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    @MainActor
    func resetPassword(email: String) async {
        do {
            try await supabase.auth.resetPasswordForEmail(email)
        } catch {
            self.error = error.localizedDescription
        }
    }
} 