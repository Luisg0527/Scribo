import SwiftUI
import UIKit
import PhotosUI
import Photos
import UniformTypeIdentifiers
import AVFoundation
import VisionKit
import StoreKit

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @State private var isSidebarShowing: Bool = false
    @State private var selectedTab: Int = 0
    @State private var everythingCreateNotePresented = false
    @State private var everythingCreateNotePhotos: [PendingNotePhoto] = []
    @State private var everythingCreateNoteBody: String = ""
    @State private var everythingCreateNoteCameraPresented = false
    @State private var everythingCreateNoteDocPickerPresented = false
    @State private var everythingCreateNotePickedDocument: URL?
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
                    // Match `DocumentManagerView` / Notebook (`Color.appBackground`) so the strip above the tab bar
                    // isn’t system white while the grid uses grouped grey.
                    Color.appBackground
                        .ignoresSafeArea()
                    VStack(spacing: 0) {
                        mainContentView
                        if selectedTab == 0 && !(noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil) {
                            EverythingTabAddNoteBar {
                                everythingCreateNotePhotos = []
                                everythingCreateNoteBody = ""
                                everythingCreateNotePresented = true
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if !(noteDisplayState.isShowingNote && noteDisplayState.currentNote != nil) {
                            mainTabBar
                        }
                    }
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: selectedTab)
                    .animation(.easeInOut(duration: 0.22), value: noteDisplayState.isShowingNote)
                    .animation(.easeInOut(duration: 0.22), value: noteDisplayState.currentNote?.id)
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
            .fullScreenCover(isPresented: $everythingCreateNotePresented) {
                CreateNoteSheetView(
                    isPresented: $everythingCreateNotePresented,
                    pendingPhotos: $everythingCreateNotePhotos,
                    noteBody: $everythingCreateNoteBody,
                    dataManager: dataManager,
                    onRequestCamera: { everythingCreateNoteCameraPresented = true },
                    onRequestDocument: { everythingCreateNoteDocPickerPresented = true }
                )
            }
            .fullScreenCover(isPresented: $everythingCreateNoteCameraPresented) {
                CameraView { image in
                    if let image = image {
                        handleEverythingCreateNoteCameraImage(image)
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $everythingCreateNoteDocPickerPresented) {
                DocumentPicker(selectedDocument: $everythingCreateNotePickedDocument)
            }
            .onChange(of: everythingCreateNotePickedDocument) { _, newValue in
                guard let url = newValue else { return }
                Task {
                    await handleEverythingCreateNotePickedDocument(url: url)
                    await MainActor.run { everythingCreateNotePickedDocument = nil }
                }
            }
        }
    }

    private func mergeEverythingCreateNoteDraft(photos: [PendingNotePhoto], text: String) {
        if everythingCreateNotePresented {
            everythingCreateNotePhotos.append(contentsOf: photos)
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                if everythingCreateNoteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    everythingCreateNoteBody = t
                } else {
                    everythingCreateNoteBody += "\n\n" + t
                }
            }
        } else {
            everythingCreateNotePhotos = photos
            everythingCreateNoteBody = text
            everythingCreateNotePresented = true
        }
    }

    private func handleEverythingCreateNoteCameraImage(_ image: UIImage) {
        let entry = PendingNotePhoto(image: image, photoLibraryAssetId: nil)
        mergeEverythingCreateNoteDraft(photos: [entry], text: "")
    }

    private func handleEverythingCreateNotePickedDocument(url: URL) async {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsAccess { url.stopAccessingSecurityScopedResource() }
        }
        let (photos, text) = CreateNoteDraftDocument.load(url: url)
        await MainActor.run {
            if photos.isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                alertManager.alertTitle = "Couldn’t read file"
                alertManager.alertMessage = "Try an image, PDF, or plain text."
                alertManager.alertRecoverySuggestion = ""
                alertManager.showAlert = true
                return
            }
            mergeEverythingCreateNoteDraft(photos: photos, text: text)
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

    /// Same idea as `SidebarView` fades: clear → opaque so the bar blends into content above.
    private var tabBarEdgeFadeHeight: CGFloat { 26 }

    private var mainTabBar: some View {
        let mainGray: Color = Color(hex: "#F2F2F7")

        return HStack(spacing: 0) {
            tabBarButton(title: "Everything", icon: "xmark.triangle.circle.square.fill", tag: 0)
            tabBarButton(title: "Notebook", icon: "book.fill", tag: 1)
            //tabBarButton(title: "Study", icon: "capsule.on.capsule.fill", tag: 2)
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            ZStack(alignment: .top) {
                mainGray
                VStack(spacing: 0) {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: mainGray, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: tabBarEdgeFadeHeight)
                    Spacer(minLength: 0)
                }
            }
            // Fills the strip under the home indicator (bottom safe area) with the same gray
            .ignoresSafeArea(edges: .bottom)
        )
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

// MARK: - Tab bar content blend (Notebook, Study, etc.)

/// Bottom fade that matches `mainTabBar`’s top gradient (`clear` → `#F2F2F7`) so content blends into the bar.
struct TabBarContentBottomFade: View {
    private let height: CGFloat = 26
    private var barGray: Color { Color(hex: "#F2F2F7") }

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: barGray, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}

/// Top fade over scroll content: `appBackground` at the header seam → `clear` downward into the list.
struct ScrollContentTopFade: View {
    private let height: CGFloat = 28

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white, location: 0.0),
                .init(color: .clear, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Study Placeholder View

struct StudyPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "capsule.on.capsule.fill")
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
        .overlay(alignment: .bottom) {
            TabBarContentBottomFade()
        }
        .background(Color.featureCalloutBackground)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NoteDisplayState())
            .environmentObject(AuthManager())
            .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
            .previewDisplayName("iPhone 16 Pro")
    }
}
