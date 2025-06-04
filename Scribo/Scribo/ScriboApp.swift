import SwiftUI

@main
struct ScriboApp: App {
    @StateObject private var noteDisplayState = NoteDisplayState()
    @StateObject private var authManager = AuthManager()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isLoading = true
    @State private var isAuthChecked = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading || !isAuthChecked {
                    LaunchScreenView()
                        .transition(.opacity)
                        .onAppear {
                            // Check authentication
                            Task {
                                await authManager.checkSession()
                                isAuthChecked = true
                            }
                            
                            // Show launch screen for at least 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isLoading = false
                                }
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(noteDisplayState)
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(isDarkMode ? .light : .dark)
            .onChange(of: isDarkMode) { oldValue, newValue in
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.forEach { window in
                        window.overrideUserInterfaceStyle = newValue ? .light : .dark
                    }
                }
            }
            .onAppear {
                // Set initial color scheme
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.forEach { window in
                        window.overrideUserInterfaceStyle = isDarkMode ? .light : .dark
                    }
                }
            }
        }
    }
}
