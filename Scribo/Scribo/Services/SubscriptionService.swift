import Foundation
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var currentSubscriptionTier: SubscriptionTier = .free
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let productIdentifiers = [
        "com.dauntless.scribos.pro.monthly",
        "com.dauntless.scribos.pro.yearly",
        "com.dauntless.scribos.premium.monthly",
        "com.dauntless.scribos.premium.yearly"
    ]

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIdentifiers)
            print("✅ Loaded \(products.count) products")
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }

    // MARK: - Purchase Management

    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                await handlePurchaseSuccess(verification)
            case .userCancelled:
                print("❌ Purchase cancelled by user")
                throw SubscriptionError.userCancelled
            case .pending:
                print("⏳ Purchase pending")
                throw SubscriptionError.pending
            @unknown default:
                print("❌ Unknown purchase result")
                throw SubscriptionError.unknown
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            throw error
        }
    }

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ Purchases restored successfully")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            throw error
        }
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        do {
            var highestTier: SubscriptionTier = .free

            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    let tier = getSubscriptionTier(for: transaction.productID)
                    if tier.rawValue > highestTier.rawValue {
                        highestTier = tier
                    }
                }
            }

            currentSubscriptionTier = highestTier
            print("✅ Current subscription tier: \(highestTier.displayName)")

            // Update user profile in database
            await updateUserSubscriptionInDatabase(tier: highestTier)

        } catch {
            print("❌ Failed to update subscription status: \(error)")
        }
    }

    private func handlePurchaseSuccess(_ verification: VerificationResult<StoreKit.Transaction>) async {
        do {
            if case .verified(let transaction) = verification {
                // Update subscription status
                await updateSubscriptionStatus()

                // Play success sound
                SoundManager.shared.playCompletionSound()

                print("✅ Purchase successful: \(transaction.productID)")
            } else {
                print("❌ Transaction verification failed")
                throw SubscriptionError.verificationFailed
            }
        } catch {
            print("❌ Failed to handle purchase success: \(error)")
            errorMessage = "Failed to process purchase"
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        if case .verified(let transaction) = result {
            await updateSubscriptionStatus()

            // Finish the transaction
            await transaction.finish()
        }
    }

    // MARK: - Helper Methods

    private func getSubscriptionTier(for productID: String) -> SubscriptionTier {
        if productID.contains("premium") {
            return .premium
        } else if productID.contains("pro") {
            return .pro
        } else {
            return .free
        }
    }

    private func updateUserSubscriptionInDatabase(tier: SubscriptionTier) async {
        do {
            try await DataManager.shared.updateUserSubscription(tier: tier)
            print("✅ Updated user subscription to \(tier.displayName) in database")
        } catch {
            print("❌ Failed to update user subscription in database: \(error)")
        }
    }

    // MARK: - Feature Access

    func canCreateNote() -> Bool {
        let currentNoteCount = DataManager.shared.topics.flatMap { $0.subtopics }.flatMap { $0.notes }.count
        let limit = currentSubscriptionTier.limits.maxNotes

        return limit == -1 || currentNoteCount < limit
    }

    func canAddPhotoToNote(currentPhotoCount: Int) -> Bool {
        let limit = currentSubscriptionTier.limits.maxPhotosPerNote
        return limit == -1 || currentPhotoCount < limit
    }

    func canUseAIChat() -> Bool {
        // This would check against daily limits
        // For now, return true for pro and premium
        return currentSubscriptionTier != .free
    }

    func canUseOCR() -> Bool {
        // This would check against daily limits
        // For now, return true for pro and premium
        return currentSubscriptionTier != .free
    }

    func getRemainingNotes() -> Int? {
        let currentNoteCount = DataManager.shared.topics.flatMap { $0.subtopics }.flatMap { $0.notes }.count
        let limit = currentSubscriptionTier.limits.maxNotes

        if limit == -1 {
            return nil // Unlimited
        }

        return max(0, limit - currentNoteCount)
    }
}

// MARK: - Subscription Errors

enum SubscriptionError: LocalizedError {
    case userCancelled
    case pending
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending approval"
        case .verificationFailed:
            return "Purchase verification failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
