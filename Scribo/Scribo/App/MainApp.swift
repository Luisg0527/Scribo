import SwiftUI

@main
struct ScriboApp: App {
    @StateObject private var noteDisplayState = NoteDisplayState()
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                HomeView()
                    .environmentObject(noteDisplayState)
                    .environmentObject(authManager)
            } else {
                LoginView(authManager: authManager)
            }
        }
    }
} 