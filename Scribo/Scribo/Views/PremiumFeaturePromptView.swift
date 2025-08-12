import SwiftUI

struct PremiumFeaturePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    let feature: PremiumFeature
    let currentUsage: Int
    let limit: Int
    let onUpgrade: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Popup card with buttons at bottom
            VStack(spacing: 16) {
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Limit Reached")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(feature.shortMessage)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Action buttons at bottom
                HStack(spacing: 16) {
                    Button("Go Back") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                    
                    Button("Upgrade") {
                        onUpgrade()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.featureCalloutAccent)
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "1b1a21").opacity(0.95),
                                Color.featureCalloutAccent.opacity(0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .scale))
    }
}

enum PremiumFeature {
    case notes
    case photos
    case aiChat
    case ocr
    
    var icon: String {
        switch self {
        case .notes: return "note.text"
        case .photos: return "photo.on.rectangle"
        case .aiChat: return "message.and.waveform"
        case .ocr: return "doc.text.viewfinder"
        }
    }
    
    var shortMessage: String {
        switch self {
        case .notes:
            return "You've reached your 50 note limit. Upgrade to create unlimited notes."
        case .photos:
            return "You've reached your photo limit. Upgrade for unlimited attachments."
        case .aiChat:
            return "You've reached your daily AI chat limit. Upgrade for unlimited access."
        case .ocr:
            return "You've reached your daily OCR limit. Upgrade for unlimited processing."
        }
    }
    
    var upgradeMessage: String {
        switch self {
        case .notes:
            return "You've reached your note limit. Upgrade to create unlimited notes and organize your thoughts without restrictions."
        case .photos:
            return "You've reached your photo attachment limit. Upgrade to add unlimited photos to your notes."
        case .aiChat:
            return "You've reached your daily AI chat limit. Upgrade to chat with AI assistant without restrictions."
        case .ocr:
            return "You've reached your daily OCR processing limit. Upgrade to extract text from unlimited documents."
        }
    }
    
    var benefits: [String] {
        switch self {
        case .notes:
            return [
                "Unlimited notes creation",
                "Advanced organization features",
                "Priority support",
                "Cloud backup"
            ]
        case .photos:
            return [
                "Unlimited photo attachments",
                "High-quality image processing",
                "Advanced photo organization",
                "Cloud storage for images"
            ]
        case .aiChat:
            return [
                "Unlimited AI conversations",
                "Advanced AI features",
                "Priority response times",
                "Custom AI training"
            ]
        case .ocr:
            return [
                "Unlimited OCR processing",
                "Advanced text extraction",
                "Multi-language support",
                "Batch processing"
            ]
        }
    }
}

#Preview {
    PremiumFeaturePromptView(
        feature: .notes,
        currentUsage: 45,
        limit: 50,
        onUpgrade: {}
    )
}
