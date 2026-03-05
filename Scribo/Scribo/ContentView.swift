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
    @State private var showNotebook: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var alertManager = AlertManager()
    @State private var sidebarDragOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            if authManager.isAuthenticated {
                mainView
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
            let sidebarWidth = geometry.size.width * 0.9
            let contentOffset = isSidebarShowing ? max(sidebarWidth + sidebarDragOffset, 0) : 0
            let openRatio = sidebarWidth > 0 ? min(max(contentOffset / sidebarWidth, 0), 1) : 0
            
            ZStack(alignment: .leading) {
                // 1. Sidebar: drawn first, "beside" the content; can be dragged left to close
                if isSidebarShowing {
                    SidebarView(isShowing: $isSidebarShowing, authManager: authManager)
                        .frame(width: sidebarWidth, height: geometry.size.height)
                        .ignoresSafeArea(edges: .vertical)
                        .transition(.move(edge: .leading))
                        .contentShape(Rectangle())
                        .gesture(
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
                
                // 2. Main content: full-size layer that slides right; overlay inside so it moves with it and darkens by open amount
            ZStack {
                Color.featureCalloutBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                        if showNotebook || (noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil) {
                        topBarView
                    }
                    mainContentView
                }
                
                    // Full-content overlay: covers entire view, moves with content, gradient darkness by open ratio (dynamic, not anim)
                    // Hit testing disabled so buttons in the content stay tappable; close via drag or hamburger
                    LinearGradient(
                        colors: [
                            Color.black.opacity(openRatio * 0.55),
                            Color.black.opacity(openRatio * 0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())                 // makes the whole thing tappable
                    .allowsHitTesting(isSidebarShowing)         // only intercept taps when open
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            isSidebarShowing = false
                            sidebarDragOffset = 0
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: contentOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: contentOffset)
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
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
    
    private var mainContentView: some View {
        Group {
            if showNotebook {
                NotebookView(isPresented: $showNotebook)
                    .environmentObject(noteDisplayState)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
            } else if noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil {
                NavigationView {
                    NoteView(note: noteDisplayState.currentNote, isPresented: $showNotebook, dataManager: dataManager)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
            } else {
                DocumentManagerView(showNotebook: $showNotebook, onOpenMenu: { isSidebarShowing.toggle() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showNotebook)
        .animation(.easeInOut(duration: 0.2), value: noteDisplayState.isShowingNote)
    }
    
    private var topBarView: some View {
        VStack(spacing: 0) {
            HStack {
                menuButton
                Spacer()
            }
            .background(Color.clear)
        }
    }
    
    private var menuButton: some View {
        Button(action: {
            withAnimation {
                isSidebarShowing.toggle()
            }
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20))
                .foregroundColor(.featureCalloutAccent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
