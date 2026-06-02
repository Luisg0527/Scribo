import SwiftUI
import StoreKit

// MARK: - Full-screen premium paywall

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedBilling: BillingPeriod = .yearly
    @State private var showingPurchaseAlert = false
    @State private var purchaseError: String?
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false

    private var selectedProduct: Product? {
        storeProduct(billing: selectedBilling)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroHeader
                            .padding(.bottom, 28)

                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(PremiumBenefit.highlighted) { benefit in
                                PremiumBenefitRow(benefit: benefit)
                            }
                        }

                        if subscriptionManager.currentSubscriptionTier != .free {
                            currentPlanBanner
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 20)

                        planSection(cardMinHeight: max(148, geo.size.height * 0.14))

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity)

                    bottomBar
                }

                closeButton
            }
        }
        .alert("Purchase Error", isPresented: $showingPurchaseAlert) {
            Button("OK") { }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showTermsOfUse) {
            NavigationStack {
                TermsOfUse()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showTermsOfUse = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicy()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showPrivacyPolicy = false }
                        }
                    }
            }
        }
        .onAppear {
            Task {
                await subscriptionManager.loadProducts()
                syncSelectionFromProducts()
            }
        }
        .onChange(of: subscriptionManager.products.count) { _, _ in
            syncSelectionFromProducts()
        }
    }

    // MARK: - Sections

    private var background: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(hex: "1C1C1E"), Color(hex: "232329")]
                : [Color(hex: "FFFFFF"), Color(hex: "F4F6FF")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var textPrimary: Color {
        colorScheme == .dark ? Color(hex: "FBFBFE") : Color(hex: "1A1B2E")
    }

    private var textSecondary: Color {
        textPrimary.opacity(0.65)
    }

    private var heroHeader: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Say hello to your best notes.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Premium includes unlimited notes, AI help, and more.")
                    .font(.system(size: 17))
                    .foregroundColor(textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 108)
            .padding(.top, 44)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.appAccent1.opacity(0.22),
                                Color.appAccent1.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)
                Image("ScriboIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            }
            .offset(x: 8, y: 0)
        }
    }

    private func planSection(cardMinHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("Select a plan")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)

            HStack(alignment: .top, spacing: 14) {
                planCard(billing: .yearly, minHeight: cardMinHeight)
                planCard(billing: .monthly, minHeight: cardMinHeight)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 20)

            Text("Change plans or cancel anytime.")
                .font(.system(size: 15))
                .foregroundColor(textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .layoutPriority(1)
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(textPrimary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.top, 12)
        }
    }

    private var currentPlanBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(Color.appAccent1)
            Text("Current plan: \(subscriptionManager.currentSubscriptionTier.displayName)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appAccent1.opacity(0.12))
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Button {
                guard let product = selectedProduct else { return }
                Task { await purchaseSubscription(product) }
            } label: {
                HStack(spacing: 8) {
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.appAccent1)
                )
            }
            .disabled(selectedProduct == nil || subscriptionManager.isLoading)

            HStack(spacing: 8) {
                Button("Restore Purchases") {
                    Task { await restorePurchases() }
                }
                Text("·").foregroundColor(textSecondary.opacity(0.5))
                Button("Terms of Use") { showTermsOfUse = true }
                Text("·").foregroundColor(textSecondary.opacity(0.5))
                Button("Privacy Policy") { showPrivacyPolicy = true }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(textSecondary)
            .disabled(subscriptionManager.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .safeAreaPadding(.bottom, 12)
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else {
            return "Subscribe to Premium"
        }
        return "Continue with Premium · \(product.displayPrice)"
    }

    // MARK: - Plan cards

    private func planCard(billing: BillingPeriod, minHeight: CGFloat) -> some View {
        let isSelected = selectedBilling == billing
        let product = storeProduct(billing: billing)
        let monthlyProduct = storeProduct(billing: .monthly)
        let savings = savingsLabel(yearly: billing == .yearly ? product : nil, monthly: monthlyProduct)
        let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedBilling = billing
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer(minLength: 0)
                    selectionIndicator(isSelected: isSelected)
                }

                Text(billing.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textPrimary)

                Text(priceLine(product: product, billing: billing))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if billing == .yearly, let monthlyProduct {
                    Text(strikethroughYearly(from: monthlyProduct))
                        .font(.system(size: 12))
                        .foregroundColor(textSecondary)
                        .strikethrough()
                        .lineLimit(1)
                }

                Text(billing.billingFootnote)
                    .font(.system(size: 11))
                    .foregroundColor(textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .padding(.top, savings != nil && billing == .yearly ? 10 : 0)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background {
                cardShape
                    .fill(cardFill)
                    .shadow(
                        color: isSelected ? Color.appAccent1.opacity(0.18) : Color.black.opacity(0.07),
                        radius: isSelected ? 12 : 8,
                        y: 4
                    )
            }
            .overlay {
                cardShape
                    .stroke(isSelected ? Color.appAccent1 : textPrimary.opacity(0.14), lineWidth: isSelected ? 2.5 : 1)
            }
            .overlay(alignment: .top) {
                if let savings, billing == .yearly {
                    Text(savings)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color(hex: "34C759")))
                        .offset(y: -11)
                }
            }
            .clipShape(cardShape)
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.appAccent1 : textPrimary.opacity(0.22), lineWidth: 2)
                .frame(width: 26, height: 26)
            if isSelected {
                Circle()
                    .fill(Color.appAccent1)
                    .frame(width: 26, height: 26)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    // MARK: - StoreKit helpers

    private func storeProduct(billing: BillingPeriod) -> Product? {
        subscriptionManager.products.first { product in
            product.id.contains(SubscriptionTier.premium.rawValue)
                && product.id.contains(billing.productKeyword)
        }
    }

    private func syncSelectionFromProducts() {
        if storeProduct(billing: selectedBilling) == nil {
            if storeProduct(billing: .yearly) != nil {
                selectedBilling = .yearly
            } else if storeProduct(billing: .monthly) != nil {
                selectedBilling = .monthly
            }
        }
    }

    private func priceLine(product: Product?, billing: BillingPeriod) -> String {
        if let product {
            return billing == .yearly ? "\(product.displayPrice)/YR" : "\(product.displayPrice)/MO"
        }
        return billing == .yearly ? fallbackYearlyPrice : fallbackMonthlyPrice
    }

    private var fallbackMonthlyPrice: String { "$9.99/MO" }

    private var fallbackYearlyPrice: String { "$99.99/YR" }

    private func strikethroughYearly(from monthly: Product) -> String {
        let annual = monthly.price * 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = monthly.priceFormatStyle.locale
        let value = formatter.string(from: annual as NSDecimalNumber) ?? annual.formatted(monthly.priceFormatStyle)
        return "\(value)/YR"
    }

    private func savingsLabel(yearly: Product?, monthly: Product?) -> String? {
        guard let yearly, let monthly else { return nil }
        let annualFromMonthly = monthly.price * 12
        guard annualFromMonthly > yearly.price else { return nil }
        let saved = (annualFromMonthly - yearly.price) / annualFromMonthly * 100
        var rounded = Decimal()
        var value = saved
        NSDecimalRound(&rounded, &value, 0, .plain)
        let percent = NSDecimalNumber(decimal: rounded).intValue
        guard percent > 0 else { return nil }
        return "\(percent)% SAVINGS"
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

// MARK: - Billing period

private enum BillingPeriod: CaseIterable {
    case yearly
    case monthly

    var title: String {
        switch self {
        case .yearly: return "YEARLY"
        case .monthly: return "MONTHLY"
        }
    }

    var productKeyword: String {
        switch self {
        case .yearly: return "yearly"
        case .monthly: return "monthly"
        }
    }

    var billingFootnote: String {
        switch self {
        case .yearly: return "Billed yearly. Cancel anytime."
        case .monthly: return "Billed monthly. Cancel anytime."
        }
    }
}

// MARK: - Benefits

private struct PremiumBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String

    static let highlighted: [PremiumBenefit] = [
        PremiumBenefit(
            icon: "sparkles",
            title: "AI Chat Assistant",
            subtitle: "Get help writing, summarizing, and organizing your notes."
        ),
        PremiumBenefit(
            icon: "doc.text.viewfinder",
            title: "OCR & Smart Capture",
            subtitle: "Turn photos and scans into searchable text instantly."
        ),
        PremiumBenefit(
            icon: "infinity",
            title: "Unlimited Notes",
            subtitle: "Capture every idea without hitting a limit."
        )
    ]
}

private struct PremiumBenefitRow: View {
    let benefit: PremiumBenefit
    @Environment(\.colorScheme) private var colorScheme

    private var textPrimary: Color {
        colorScheme == .dark ? Color(hex: "FBFBFE") : Color(hex: "1A1B2E")
    }

    private var textSecondary: Color {
        textPrimary.opacity(0.65)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.appAccent1)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(benefit.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text(benefit.subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SubscriptionView()
}
