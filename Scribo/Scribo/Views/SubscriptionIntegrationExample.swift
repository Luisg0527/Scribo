import SwiftUI

// MARK: - Subscription Integration Example
// This file shows how to integrate the subscription system into your app

struct SubscriptionIntegrationExample: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingSubscriptionView = false
    @State private var showingPremiumPrompt = false
    @State private var currentFeature: PremiumFeature = .notes
    
    var body: some View {
        VStack {
            Text("Subscription Integration Example")
                .font(.title)
                .padding()
            
            // Example: Check if user can create a note
            Button("Create Note") {
                checkNoteCreation()
            }
            .padding()
            
            // Example: Check if user can use AI chat
            Button("Use AI Chat") {
                checkAIChatAccess()
            }
            .padding()
            
            // Example: Check if user can use OCR
            Button("Use OCR") {
                checkOCRAccess()
            }
            .padding()
            
            // Show current subscription status
            VStack {
                Text("Current Plan: \(subscriptionManager.currentSubscriptionTier.displayName)")
                    .font(.headline)
                
                if let remainingNotes = subscriptionManager.getRemainingNotes() {
                    Text("Notes remaining: \(remainingNotes)")
                        .font(.subheadline)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
        .overlay(
            Group {
                if showingPremiumPrompt {
                    PremiumFeaturePromptView(
                        feature: currentFeature,
                        currentUsage: getCurrentUsage(for: currentFeature),
                        limit: getLimit(for: currentFeature),
                        onUpgrade: {
                            showingPremiumPrompt = false
                            showingSubscriptionView = true
                        }
                    )
                }
            }
        )
    }
    
    // MARK: - Feature Access Checks
    
    private func checkNoteCreation() {
        if subscriptionManager.canCreateNote() {
            // Proceed with note creation
            createNote()
        } else {
            // Show premium prompt
            currentFeature = .notes
            showingPremiumPrompt = true
        }
    }
    
    private func checkAIChatAccess() {
        if subscriptionManager.canUseAIChat() {
            // Proceed with AI chat
            openAIChat()
        } else {
            // Show premium prompt
            currentFeature = .aiChat
            showingPremiumPrompt = true
        }
    }
    
    private func checkOCRAccess() {
        if subscriptionManager.canUseOCR() {
            // Proceed with OCR
            processOCR()
        } else {
            // Show premium prompt
            currentFeature = .ocr
            showingPremiumPrompt = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func createNote() {
        print("✅ Creating note...")
        // Your note creation logic here
    }
    
    private func openAIChat() {
        print("✅ Opening AI chat...")
        // Your AI chat logic here
    }
    
    private func processOCR() {
        print("✅ Processing OCR...")
        // Your OCR logic here
    }
    
    private func getCurrentUsage(for feature: PremiumFeature) -> Int {
        switch feature {
        case .notes:
            return DataManager.shared.topics.flatMap { $0.subtopics }.flatMap { $0.notes }.count
        case .photos:
            return 0 // Would track photo count
        case .aiChat:
            return 0 // Would track daily AI chat usage
        case .ocr:
            return 0 // Would track daily OCR usage
        }
    }
    
    private func getLimit(for feature: PremiumFeature) -> Int {
        let limits = subscriptionManager.currentSubscriptionTier.limits
        
        switch feature {
        case .notes:
            return limits.maxNotes
        case .photos:
            return limits.maxPhotosPerNote
        case .aiChat:
            return limits.aiChatMessagesPerDay
        case .ocr:
            return limits.ocrProcessingPerDay
        }
    }
}

// MARK: - Integration in ContentView

/*
To integrate this into your ContentView, add these properties:

@StateObject private var subscriptionManager = SubscriptionManager.shared
@State private var showingSubscriptionView = false
@State private var showingPremiumPrompt = false
@State private var currentFeature: PremiumFeature = .notes

Then add this method to check feature access:

private func checkFeatureAccess(_ feature: PremiumFeature, action: @escaping () -> Void) {
    let canAccess: Bool
    
    switch feature {
    case .notes:
        canAccess = subscriptionManager.canCreateNote()
    case .photos:
        canAccess = subscriptionManager.canAddPhotoToNote(currentPhotoCount: 0)
    case .aiChat:
        canAccess = subscriptionManager.canUseAIChat()
    case .ocr:
        canAccess = subscriptionManager.canUseOCR()
    }
    
    if canAccess {
        action()
    } else {
        currentFeature = feature
        showingPremiumPrompt = true
    }
}

And add these sheets to your view:

.sheet(isPresented: $showingSubscriptionView) {
    SubscriptionView()
}
.sheet(isPresented: $showingPremiumPrompt) {
    PremiumFeaturePromptView(
        feature: currentFeature,
        currentUsage: getCurrentUsage(for: currentFeature),
        limit: getLimit(for: currentFeature)
    )
}
*/

#Preview {
    SubscriptionIntegrationExample()
}
