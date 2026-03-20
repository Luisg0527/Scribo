import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var showingPurchaseAlert = false
    @State private var purchaseError: String?
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        ZStack {
            // Background using ChatView colors
            AppColors.featureCalloutBackgroundWarm(for: isDarkMode ? .dark : .light)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with Bumble-style design
                VStack(spacing: 22) {
                    // ScriboIcon with glow effect
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 95, height: 95)
                            .blur(radius: 17)

                        Image("ScriboIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .shadow(color: .black.opacity(0.3), radius: 9, x: 0, y: 4)
                    }
                    .padding(.top, 55)

                    VStack(spacing: 10) {
                        Text("Unlock Premium")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Take your notes to the next level")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 30)

                // Horizontal scrolling subscription cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                            BumbleStyleSubscriptionCard(
                                tier: tier,
                                isSelected: selectedProduct?.id.contains(tier.rawValue) == true,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectProduct(for: tier)
                                    }
                                }
                            )
                            .frame(width: 300, height: 440)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 25)

                // Current Status
                if subscriptionManager.currentSubscriptionTier != .free {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                            Text("Current Plan: \(subscriptionManager.currentSubscriptionTier.displayName)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        if let remainingNotes = subscriptionManager.getRemainingNotes() {
                            Text("\(remainingNotes) notes remaining")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }

                // Action Buttons
                VStack(spacing: 18) {
                    if let selectedProduct = selectedProduct {
                        Button(action: {
                            Task {
                                await purchaseSubscription(selectedProduct)
                            }
                        }) {
                            HStack {
                                if subscriptionManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.75)
                                } else {
                                    Text("Start Premium")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.2), radius: 9, x: 0, y: 4)
                            )
                            .foregroundColor(Color.featureCalloutAccent)
                        }
                        .disabled(subscriptionManager.isLoading)

                        Text("\(selectedProduct.displayPrice) per month")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Button("Restore Purchases") {
                        Task {
                            await restorePurchases()
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .disabled(subscriptionManager.isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                // Terms and Privacy - moved up to avoid phone corners
                VStack(spacing: 10) {
                    Text("By subscribing, you agree to our Terms of Service and Privacy Policy")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    HStack(spacing: 28) {
                        Button("Terms of Service") {
                            // TODO: Show terms
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                        Button("Privacy Policy") {
                            // TODO: Show privacy policy
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 50) // Just right padding
            }

            // Close button in top-right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        }
        .alert("Purchase Error", isPresented: $showingPurchaseAlert) {
            Button("OK") { }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func selectProduct(for tier: SubscriptionTier) {
        // Find the monthly product for the selected tier
        selectedProduct = subscriptionManager.products.first { product in
            product.id.contains(tier.rawValue) && product.id.contains("monthly")
        }
    }

    private func purchaseSubscription(_ product: Product) async {
        do {
            try await subscriptionManager.purchase(product)
            dismiss()
        } catch {
            purchaseError = error.localizedDescription
            showingPurchaseAlert = true
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
        } catch {
            purchaseError = error.localizedDescription
            showingPurchaseAlert = true
        }
    }
}

struct BumbleStyleSubscriptionCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header with tier info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(tier.displayName)
                                        .font(.system(size: 26, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)

                                    if tier == .pro {
                                        Text("MOST POPULAR")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(7)
                                    }
                                }

                                Text(tier.description)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tier.price)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            if tier != .free {
                                Text("per month")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }

                    // Features list
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(tier.features, id: \.self) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 15, weight: .semibold))

                                Text(feature)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                        }
                    }
                }
                .padding(22)
            }
            .scrollIndicators(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isSelected ? 0.25 : 0.15),
                                Color.white.opacity(isSelected ? 0.15 : 0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                Color.white.opacity(isSelected ? 0.5 : 0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? .black.opacity(0.3) : .black.opacity(0.1),
                radius: isSelected ? 14 : 7,
                x: 0,
                y: isSelected ? 7 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    SubscriptionView()
}
