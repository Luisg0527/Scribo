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
    @Published var isResettingPassword = false
    
    private let supabase = SupabaseConfig.shared.client
    
    private func handleAuthError(_ error: Error) -> String {
        let errorMessage = error.localizedDescription.lowercased()
        
        // Handle common authentication errors
        if errorMessage.contains("invalid login credentials") {
            return "Incorrect email or password. Please try again."
        } else if errorMessage.contains("email not confirmed") {
            return "Please verify your email address before logging in."
        } else if errorMessage.contains("email already registered") {
            return "This email is already registered. Please try logging in instead."
        } else if errorMessage.contains("password should be at least 6 characters") {
            return "Password must be at least 6 characters long."
        } else if errorMessage.contains("invalid email") {
            return "Please enter a valid email address."
        } else if errorMessage.contains("rate limit") {
            return "Too many attempts. Please try again in a few minutes."
        } else if errorMessage.contains("network") {
            return "Network error. Please check your internet connection."
        } else if errorMessage.contains("expired") {
            return "Your session has expired. Please log in again."
        }
        
        // Default error message
        return "An error occurred. Please try again."
    }
    
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
            self.error = handleAuthError(error)
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
            self.error = handleAuthError(error)
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
            print("📧 Attempting to send reset password email to: \(email)")
            let redirectTo = URL(string: "scribo://reset-password")!
            try await supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo)
            print("✅ Reset password email sent successfully")
        } catch {
            print("❌ Failed to send reset password email: \(error.localizedDescription)")
            self.error = handleAuthError(error)
        }
    }
    
    @MainActor
    func handlePasswordReset(url: URL) async {
        do {
            print("🔑 Processing password reset URL")
            
            // Check for error in URL
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let queryItems = components.queryItems,
               let error = queryItems.first(where: { $0.name == "error" })?.value {
                print("❌ Error in reset URL: \(error)")
                if error == "access_denied" {
                    self.error = "The password reset link has expired. Please request a new one."
                    return
                }
            }
            
            // Extract the tokens from the URL
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let fragment = components.fragment else {
                print("❌ Invalid URL format - missing fragment")
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid reset password URL"])
            }
            
            print("📝 URL fragment: \(fragment)")
            
            // Parse the fragment to get access_token and refresh_token
            let params = fragment.split(separator: "&")
            var accessToken: String?
            var refreshToken: String?
            
            for param in params {
                let parts = param.split(separator: "=")
                if parts.count == 2 {
                    let key = String(parts[0])
                    let value = String(parts[1])
                    if key == "access_token" {
                        accessToken = value
                    } else if key == "refresh_token" {
                        refreshToken = value
                    }
                }
            }
            
            guard let accessToken = accessToken, let refreshToken = refreshToken else {
                print("❌ Missing tokens in URL")
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing tokens in reset password URL"])
            }
            
            print("✅ Tokens extracted successfully")
            
            // Exchange the tokens for a session
            let session = try await supabase.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
            print("✅ Session established successfully")
            isResettingPassword = true
            print("✅ isResettingPassword set to true")
        } catch {
            print("❌ Error handling password reset: \(error.localizedDescription)")
            self.error = handleAuthError(error)
        }
    }
    
    @MainActor
    func updatePassword(newPassword: String) async {
        do {
            try await supabase.auth.update(user: UserAttributes(password: newPassword))
            isResettingPassword = false
            isAuthenticated = true
        } catch {
            self.error = handleAuthError(error)
        }
    }
    
    @MainActor
    func signInWithGoogle() async {
        do {
            let response = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "scribo://auth-callback")!
            )
            
            // The response is already a session
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
            self.error = handleAuthError(error)
        }
    }
    
    @MainActor
    func signInWithApple() async {
        do {
            let response = try await supabase.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: URL(string: "scribo://auth-callback")!
            )
            
            // The response is already a session
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
            self.error = handleAuthError(error)
        }
    }
} 