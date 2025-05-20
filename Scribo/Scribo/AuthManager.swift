import Foundation
import SwiftUI
import Supabase

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
            currentUser = session.user
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
            currentUser = response.user
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
            currentUser = response.user
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