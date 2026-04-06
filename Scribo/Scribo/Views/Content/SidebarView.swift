import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private let sidebarGradientColors: [Color] = [
    Color(hex: "E85D04"),
    Color(hex: "FF9500"),
    Color(hex: "232429"),
    Color(hex: "1C1D24")
]

private let sidebarCardDark = Color(hex: "2C2D33")
private let sidebarLabelGray = Color.white.opacity(0.5)
private let sidebarRed = Color(hex: "E53935")

struct SidebarView: View {
    @Binding var isShowing: Bool
    @ObservedObject var authManager: AuthManager
    let topInset: CGFloat

    @EnvironmentObject private var noteDisplayState: NoteDisplayState
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var alertManager = AlertManager()
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var isProfileSheetPresented = false
    @State private var isSubscriptionPresented = false
    @State private var isFeedbackPresented = false
    @AppStorage("offlineSyncEnabled") private var offlineSyncEnabled = false
    @AppStorage("spotlightSearchEnabled") private var spotlightSearchEnabled = false
    @State private var showDeleteAccountAlert = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isQRScannerPresented = false
    @State private var showCameraDeniedAlert = false

    var body: some View {
        GeometryReader { geo in
            // Scroll down → minY negative → shift gradient upward (inverse of previous max(0, -offset))
            let gradientShift = min(0, scrollOffset / 800)
            ZStack {
                // Full-screen background — shifts subtly with scroll
                LinearGradient(
                    colors: sidebarGradientColors,
                    startPoint: UnitPoint(x: 0, y: gradientShift),
                    endPoint: UnitPoint(x: 1, y: 1 + gradientShift)
                )
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.2), value: scrollOffset)

                ScrollView(showsIndicators: false) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: proxy.frame(in: .named("sidebarScroll")).minY
                            )
                    }
                    .frame(height: 0)

                    VStack(alignment: .leading, spacing: 30) {
                        Text("Never stop learning, because life never stops teaching.")
                            .font(.system(size: 26, weight: .medium, design: .serif))
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR ACCOUNT")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(sidebarLabelGray)
                            Text(email.isEmpty ? "Loading..." : email)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR PLAN")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(sidebarLabelGray)
                            Text("\(subscriptionManager.currentSubscriptionTier.displayName) Plan")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 14) {
                            Button(action: {
                                performHapticFeedback(style: .light)
                                isProfileSheetPresented = true
                            }) {
                                HStack {
                                    Text("How to get started")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().fill(sidebarCardDark)
                                )
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                performHapticFeedback(style: .light)
                                isSubscriptionPresented = true
                            }) {
                                HStack {
                                    Text("Upgrade your notebook")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule().fill(Color.appAccent1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 150)
                        .padding(.bottom, 100)

                        VStack(spacing: 0) {
                            Button(action: {
                                performHapticFeedback(style: .light)
                                isProfileSheetPresented = true
                            }) {
                                sidebarRow(title: "Settings", trailing: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                })
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.horizontal, 18)

                            Button(action: {
                                performHapticFeedback(style: .light)
                                isQRScannerPresented = true
                            }) {
                                sidebarRow(title: "Scan share QR", trailing: {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                })
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.horizontal, 18)

                            Button(action: {
                                performHapticFeedback(style: .light)
                                isFeedbackPresented = true
                            }) {
                                sidebarRow(title: "Get Help or Send Feedback", trailing: {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                })
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.horizontal, 18)

                            Button(action: {
                                performHapticFeedback(style: .light)
                                Task {
                                    await authManager.signOut()
                                    isShowing = false
                                }
                            }) {
                                sidebarRow(title: "Sign out of Scribo", trailing: {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                })
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(Color.white.opacity(0.12))
                                .padding(.horizontal, 18)

                            Button(action: {
                                performHapticFeedback(style: .medium)
                                showDeleteAccountAlert = true
                            }) {
                                sidebarRow(title: "Delete my account", trailing: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.6))
                                })
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(sidebarCardDark)
                        )
                        .padding(.horizontal, 24)

                        VStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.point.up.fill")
                                    .font(.system(size: 12))
                                Text("Swipe up for more options")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.4))

                            Text("Scribo® v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(minHeight: geo.size.height) // makes content at least full screen height
                    .padding(.top, topInset)
                }
                .coordinateSpace(name: "sidebarScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = value
                }
                .mask(
                    VStack(spacing: 0) {
                        // top fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)

                        Rectangle()
                            .fill(Color.black)

                        // bottom fade
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)
                    }
                )
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            Task {
                await loadUserInfo()
            }

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
                }
            }
        }
        .sheet(isPresented: $isProfileSheetPresented) {
            ProfileSheetView(isPresented: $isProfileSheetPresented, authManager: authManager)
        }
        .sheet(isPresented: $isSubscriptionPresented) {
            SubscriptionView()
        }
        .sheet(isPresented: $isFeedbackPresented) {
            NavigationView {
                FeedbackView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { isFeedbackPresented = false }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $isQRScannerPresented) {
            QRCodeScannerView(
                onScan: { raw in
                    isQRScannerPresented = false
                    openSharedNoteFromScannedQR(raw)
                },
                onClose: { isQRScannerPresented = false },
                onAccessFailed: {
                    isQRScannerPresented = false
                    showCameraDeniedAlert = true
                }
            )
        }
        .alert("Camera access", isPresented: $showCameraDeniedAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow camera access in Settings to scan a Scribo share QR code.")
        }
        .alert(alertManager.alertTitle, isPresented: $alertManager.showAlert) {
            Button("OK", role: .cancel) { }
            if !alertManager.alertRecoverySuggestion.isEmpty {
                Button("Try Again") { }
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
        .alert("Delete account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Implement delete account
            }
        } message: {
            Text("This will permanently delete your account and data. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private func sidebarRow<Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func openSharedNoteFromScannedQR(_ raw: String) {
        guard let link = ShareLinkTokenParser.sharedLink(fromScannedRaw: raw) else {
            alertManager.alertTitle = "Not a Scribo link"
            alertManager.alertMessage = "This QR code is not a Scribo notebook share link."
            alertManager.alertRecoverySuggestion = ""
            alertManager.showAlert = true
            return
        }
        switch link {
        case .notebookShare(let token):
            Task {
                do {
                    guard let payload = try await dataManager.fetchSharedNotebookPayload(shareToken: token) else {
                        await MainActor.run {
                            alertManager.alertTitle = "Link unavailable"
                            alertManager.alertMessage = "This notebook link may have been revoked or is invalid."
                            alertManager.alertRecoverySuggestion = ""
                            alertManager.showAlert = true
                        }
                        return
                    }
                    await dataManager.addOrUpdateSharedNotebookInLibrary(shareToken: token, payload: payload)
                    let topic = payload.asTopic()
                    await MainActor.run {
                        noteDisplayState.isReadOnlySharePresentation = true
                        noteDisplayState.sharedReadOnlyNotebook = topic
                        isShowing = false
                    }
                } catch {
                    await MainActor.run { alertManager.showError(error) }
                }
            }
        case .topicInvite(let topicId):
            Task {
                await dataManager.loadTopics()
                await MainActor.run {
                    guard let topic = dataManager.topics.first(where: { $0.id == topicId }) else {
                        alertManager.alertTitle = "Couldn’t open this topic"
                        alertManager.alertMessage =
                            "This QR links to a notebook topic on your Scribo account. After syncing, we still couldn’t find it."
                        alertManager.alertRecoverySuggestion =
                            "Make sure you’re signed into the account that created this notebook. To share the full notebook with others, use Share in the Notebook tab (link looks like …/b/…)."
                        alertManager.showAlert = true
                        return
                    }
                    noteDisplayState.isReadOnlySharePresentation = false
                    noteDisplayState.currentSubtopic = nil
                    noteDisplayState.currentNote = nil
                    noteDisplayState.isShowingNote = false
                    noteDisplayState.currentTopic = topic
                    noteDisplayState.pendingNotebookTopicToPresent = topic
                    isShowing = false
                }
            }
        case .noteShare(let token):
            Task {
                do {
                    guard let payload = try await dataManager.fetchSharedNotePayload(shareToken: token) else {
                        await MainActor.run {
                            alertManager.alertTitle = "Link unavailable"
                            alertManager.alertMessage = "This share link may have been revoked or is invalid."
                            alertManager.alertRecoverySuggestion = ""
                            alertManager.showAlert = true
                        }
                        return
                    }
                    let note = Note(
                        id: payload.note_id,
                        subtopic_id: nil,
                        workspace_id: payload.workspace_id,
                        user_id: nil,
                        title: payload.title,
                        content: payload.content,
                        created_at: payload.updated_at,
                        updated_at: payload.updated_at
                    )
                    await MainActor.run {
                        noteDisplayState.currentTopic = nil
                        noteDisplayState.currentSubtopic = nil
                        noteDisplayState.currentNote = note
                        noteDisplayState.isReadOnlySharePresentation = true
                        noteDisplayState.isShowingNote = true
                        isShowing = false
                    }
                } catch {
                    await MainActor.run { alertManager.showError(error) }
                }
            }
        }
    }

    private func loadUserInfo() async {
        do {
            let user = try await dataManager.getUserProfile()
            let userEmail = try await dataManager.getUserEmail()
            await MainActor.run {
                fullName = user.full_name
                email = userEmail
            }
        } catch { }
    }

    private func performHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if targetEnvironment(simulator)
        return // Avoid CHHapticPattern / hapticpatternlibrary.plist errors in Simulator
        #endif
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        }
    }
}
