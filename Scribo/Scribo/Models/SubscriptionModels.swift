import Foundation

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"

    /// Maps legacy stored values (e.g. `"pro"`) to the current tier set.
    static func fromStoredValue(_ raw: String?) -> SubscriptionTier {
        let value = raw?.lowercased() ?? "free"
        if value == "pro" { return .premium }
        return SubscriptionTier(rawValue: value) ?? .free
    }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }

    var description: String {
        switch self {
        case .free: return "Basic note-taking features"
        case .premium: return "Unlimited access to all features"
        }
    }

    var price: String {
        switch self {
        case .free: return "Free"
        case .premium: return "$9.99/month"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Up to 50 notes",
                "Basic note organization",
                "Camera capture",
                "Photo attachments (5 per note)",
                "Basic search",
                "Dark/Light mode"
            ]
        case .premium:
            return [
                "Unlimited notes",
                "Advanced AI classification",
                "Unlimited photo attachments",
                "OCR text extraction",
                "AI chat assistant",
                "Advanced search & filters",
                "Export notes",
                "Priority support",
                "Early access to new features"
            ]
        }
    }

    var limits: SubscriptionLimits {
        switch self {
        case .free:
            return SubscriptionLimits(
                maxNotes: 50,
                maxPhotosPerNote: 5,
                maxTopics: 10,
                maxSubtopics: 20,
                aiChatMessagesPerDay: 10,
                ocrProcessingPerDay: 5
            )
        case .premium:
            return SubscriptionLimits(
                maxNotes: -1, // Unlimited
                maxPhotosPerNote: -1, // Unlimited
                maxTopics: -1, // Unlimited
                maxSubtopics: -1, // Unlimited
                aiChatMessagesPerDay: -1, // Unlimited
                ocrProcessingPerDay: -1 // Unlimited
            )
        }
    }
}

struct SubscriptionLimits {
    let maxNotes: Int
    let maxPhotosPerNote: Int
    let maxTopics: Int
    let maxSubtopics: Int
    let aiChatMessagesPerDay: Int
    let ocrProcessingPerDay: Int

    func isUnlimited(_ limit: Int) -> Bool {
        return limit == -1
    }
}

struct SubscriptionProduct: Identifiable {
    let id: String
    let tier: SubscriptionTier
    let price: Decimal
    let localizedPrice: String
    let period: String
    let isPopular: Bool
}
