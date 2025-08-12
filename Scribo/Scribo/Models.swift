import Foundation

// MARK: - Models
struct Topic: Identifiable, Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var subtopics: [Subtopic]
    let created_at: String
    let updated_at: String
}

struct Subtopic: Identifiable, Codable {
    let id: UUID
    let topic_id: UUID
    var title: String
    var notes: [Note]
    let created_at: String
    let updated_at: String
}

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    let subtopic_id: UUID
    var title: String
    var content: String
    var attachment_urls: [String]?
    let created_at: String
    let updated_at: String
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.content == rhs.content &&
        lhs.attachment_urls == rhs.attachment_urls
    }
}

class User: Codable {
    let id: UUID
    var full_name: String
    var avatar_url: String?
    let created_at: String
    let auth_id: UUID
    var subscription_tier: SubscriptionTier?
    var subscription_expires_at: String?
}

// MARK: - Subscription Models
enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case pro = "pro"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }
    
    var description: String {
        switch self {
        case .free: return "Basic note-taking features"
        case .pro: return "Advanced features with AI assistance"
        case .premium: return "Unlimited access to all features"
        }
    }
    
    var price: String {
        switch self {
        case .free: return "Free"
        case .pro: return "$4.99/month"
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
        case .pro:
            return [
                "Up to 500 notes",
                "Advanced AI classification",
                "Unlimited photo attachments",
                "OCR text extraction",
                "AI chat assistant",
                "Advanced search & filters",
                "Export notes",
                "Priority support"
            ]
        case .premium:
            return [
                "Unlimited notes",
                "All Pro features",
                "Advanced AI features",
                "Custom themes",
                "Cloud backup",
                "Collaborative notes",
                "Advanced analytics",
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
        case .pro:
            return SubscriptionLimits(
                maxNotes: 500,
                maxPhotosPerNote: -1, // Unlimited
                maxTopics: 50,
                maxSubtopics: 100,
                aiChatMessagesPerDay: 100,
                ocrProcessingPerDay: 50
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

// MARK: - Search State
class SearchState: ObservableObject {
    @Published var searchText: String = ""
} 