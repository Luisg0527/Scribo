import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import VisionKit
import StoreKit

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @State private var isSidebarShowing: Bool = false
    @State private var selectedTab: Int = 0
    @AppStorage("isDarkMode") private var isDarkMode = true
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var alertManager = AlertManager()
    @State private var sidebarDragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                mainView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.featureCalloutBackground.ignoresSafeArea())
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
            let topInset = geometry.safeAreaInsets.top
            let sidebarWidth = geometry.size.width * 0.9
            let contentOffset = isSidebarShowing ? max(sidebarWidth + sidebarDragOffset, 0) : 0
            let openRatio = sidebarWidth > 0 ? min(max(contentOffset / sidebarWidth, 0), 1) : 0
            
            ZStack(alignment: .leading) {
                // 1. Main content: drawn first (behind); slides right when sidebar opens
                ZStack {
                    Color.featureCalloutBackground
                        .ignoresSafeArea()
                    VStack(spacing: 0) {
                        mainContentView
                        if !(noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil) {
                            mainTabBar
                        }
                    }
                    // Dim + tap-to-close overlay (single layer so it can receive taps when sidebar is open)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(openRatio * 0.55),
                                    Color.black.opacity(openRatio * 0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .allowsHitTesting(isSidebarShowing)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                isSidebarShowing = false
                                sidebarDragOffset = 0
                            }
                        }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: contentOffset)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard isSidebarShowing else { return }
                            let t = value.translation.width
                            sidebarDragOffset = max(min(0, t), -sidebarWidth)
                        }
                        .onEnded { value in
                            guard isSidebarShowing else { return }
                            let t = value.translation.width
                            let shouldClose = t < -sidebarWidth * 0.3
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                if shouldClose { isSidebarShowing = false }
                                sidebarDragOffset = 0
                            }
                        }
                )
                
                // 2. Sidebar: drawn on top so it receives taps; offset by drag so it slides with the content
                if isSidebarShowing {
                    SidebarView(isShowing: $isSidebarShowing, authManager: authManager, topInset: topInset)
                        .frame(width: sidebarWidth, height: geometry.size.height)
                        .background(Color.featureCalloutBackground2.ignoresSafeArea())
                        .offset(x: sidebarDragOffset)
                        .transition(.move(edge: .leading))
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard isSidebarShowing else { return }
                                    let w = value.translation.width, h = value.translation.height
                                    if abs(w) >= abs(h) { sidebarDragOffset = max(min(0, w), -sidebarWidth) }
                                }
                                .onEnded { value in
                                    guard isSidebarShowing else { return }
                                    let w = value.translation.width
                                    let shouldClose = w < -sidebarWidth * 0.3
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        if shouldClose { isSidebarShowing = false }
                                        sidebarDragOffset = 0
                                    }
                                }
                        )
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    private var mainContentView: some View {
        Group {
            if noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil {
                NavigationView {
                    NoteView(
                        note: noteDisplayState.currentNote!,
                        isPresented: Binding(
                            get: { noteDisplayState.isShowingNote },
                            set: { if !$0 { noteDisplayState.isShowingNote = false; noteDisplayState.currentNote = nil } }
                        ),
                        dataManager: dataManager
                    )
                }
                .environmentObject(noteDisplayState)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                Group {
                    switch selectedTab {
                    case 0:
                        DocumentManagerView(onOpenMenu: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { isSidebarShowing.toggle() }
                        })
                    case 1:
                        NotebookView(isPresented: .constant(false))
                            .environmentObject(noteDisplayState)
                    case 2:
                        StudyPlaceholderView()
                    default:
                        DocumentManagerView(onOpenMenu: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { isSidebarShowing.toggle() }
                        })
                    }
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selectedTab)
        .animation(.easeInOut(duration: 0.2), value: noteDisplayState.isShowingNote)
    }
    
    private var mainTabBar: some View {
        HStack(spacing: 0) {
            tabBarButton(title: "Everything", icon: "xmark.triangle.circle.square.fill", tag: 0)
            tabBarButton(title: "Notebook", icon: "book.fill", tag: 1)
            tabBarButton(title: "Study", icon: "brain.head.profile", tag: 2)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }
    
    private func tabBarButton(title: String, icon: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == tag ? Color.appAccent1 : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
    }
    
}

// MARK: - Study Placeholder View

struct StudyPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundColor(.featureCalloutAccent.opacity(0.8))
            Text("Work in progress")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.featureCalloutText)
            Text("AI-powered study tools are coming soon.")
                .font(.subheadline)
                .foregroundColor(.featureCalloutText.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.featureCalloutBackground)
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
