import Foundation

class User: Codable {
    let id: UUID
    var full_name: String
    var avatar_url: String?
    let created_at: String
    let updated_at: String
    var subscription_tier: String?
    var subscription_expires_at: String?
}

extension User {
    var tierEnum: SubscriptionTier {
        SubscriptionTier(rawValue: subscription_tier ?? "free") ?? .free
    }
}
