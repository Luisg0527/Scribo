import SwiftUI

private let sidebarBackgroundDark = LinearGradient(
    colors: [
        Color(hex: "E85D04"),
        Color(hex: "FF9500"),
        Color(hex: "232429"),
        Color(hex: "1C1D24")
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

private let sidebarCardDark = Color(hex: "2C2D33")
private let sidebarLabelGray = Color.white.opacity(0.5)
private let sidebarRed = Color(hex: "E53935")

struct SidebarView: View {
    @Binding var isShowing: Bool
    @ObservedObject var authManager: AuthManager
    let topInset: CGFloat

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

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen background
                sidebarBackgroundDark
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
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
