import SwiftUI
import GoogleMobileAds
import AVFoundation

@main
struct ScriboApp: App {
    @StateObject private var noteDisplayState = NoteDisplayState()
    @StateObject private var authManager = AuthManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isLoading = true
    @State private var isAuthChecked = false
    @State private var shouldShowCamera = false
    @State private var showCameraPermissionAlert = false

    init() {
        MobileAds.shared.start(completionHandler: nil)
        // Register custom fonts
        FontManager.registerFonts()
    }

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
                        .onOpenURL { url in
                            if url.scheme == "scribo" && url.host == "camera" {
                                checkCameraPermission()
                            }
                        }
                        .sheet(isPresented: $shouldShowCamera) {
                            CameraView { image in
                                if let image = image {
                                    // Handle the captured image
                                    print("Image captured from widget")
                                }
                                shouldShowCamera = false
                            }
                        }
                        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
                            Button("Cancel", role: .cancel) { }
                            Button("Open Settings") {
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsURL)
                                }
                            }
                        } message: {
                            Text("Please allow camera access in Settings to use this feature.")
                        }
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
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                shouldShowCamera = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        shouldShowCamera = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                showCameraPermissionAlert = true
            }
        @unknown default:
            DispatchQueue.main.async {
                showCameraPermissionAlert = true
            }
        }
    }
}
