# Scribo Subscription System

This document outlines the subscription-based pricing system implemented in Scribo, including feature tiers, pricing, and technical implementation details.

## Overview

Scribo offers a freemium model with three subscription tiers designed to meet different user needs:

- **Free**: Basic note-taking features with limitations
- **Pro**: Advanced features with AI assistance ($4.99/month)
- **Premium**: Unlimited access to all features ($9.99/month)

## Subscription Tiers

### Free Tier
**Price**: Free
**Features**:
- Up to 50 notes
- Basic note organization
- Camera capture
- Photo attachments (5 per note)
- Basic search
- Dark/Light mode

**Limits**:
- Notes: 50
- Photos per note: 5
- Topics: 10
- Subtopics: 20
- AI Chat messages per day: 10
- OCR processing per day: 5

### Pro Tier
**Price**: $4.99/month or $49.99/year
**Features**:
- Up to 500 notes
- Advanced AI classification
- Unlimited photo attachments
- OCR text extraction
- AI chat assistant
- Advanced search & filters
- Export notes
- Priority support

**Limits**:
- Notes: 500
- Photos per note: Unlimited
- Topics: 50
- Subtopics: 100
- AI Chat messages per day: 100
- OCR processing per day: 50

### Premium Tier
**Price**: $9.99/month or $99.99/year
**Features**:
- Unlimited notes
- All Pro features
- Advanced AI features
- Custom themes
- Cloud backup
- Collaborative notes
- Advanced analytics
- Priority support
- Early access to new features

**Limits**:
- All features: Unlimited

## Technical Implementation

### StoreKit Configuration

The subscription system uses StoreKit 2 with the following product identifiers:

- `com.dauntless.scribos.pro.monthly` - Pro Monthly ($4.99)
- `com.dauntless.scribos.pro.yearly` - Pro Yearly ($49.99)
- `com.dauntless.scribos.premium.monthly` - Premium Monthly ($9.99)
- `com.dauntless.scribos.premium.yearly` - Premium Yearly ($99.99)

### Key Components

1. **SubscriptionManager** (`Managers/SubscriptionManager.swift`)
   - Handles StoreKit integration
   - Manages subscription status
   - Provides feature access control

2. **SubscriptionView** (`Views/SubscriptionView.swift`)
   - Beautiful subscription selection UI
   - Product comparison
   - Purchase flow

3. **PremiumFeaturePromptView** (`Views/PremiumFeaturePromptView.swift`)
   - Appears when users hit limits
   - Encourages upgrades
   - Shows usage statistics

4. **Models** (`Models.swift`)
   - Subscription tier definitions
   - Feature limits
   - User subscription status

### Database Schema

The user table includes subscription fields:
```sql
ALTER TABLE users ADD COLUMN subscription_tier TEXT DEFAULT 'free';
ALTER TABLE users ADD COLUMN subscription_expires_at TIMESTAMP;
```

## Feature Access Control

### Implementation Pattern

```swift
// Check if user can perform an action
if !subscriptionManager.canCreateNote() {
    // Show premium prompt
    showPremiumFeaturePrompt(feature: .notes)
    return
}

// Proceed with action
createNote()
```

### Feature Checks

- **Note Creation**: `subscriptionManager.canCreateNote()`
- **Photo Attachments**: `subscriptionManager.canAddPhotoToNote(currentPhotoCount:)`
- **AI Chat**: `subscriptionManager.canUseAIChat()`
- **OCR Processing**: `subscriptionManager.canUseOCR()`

## User Experience

### Upgrade Flow

1. User hits a feature limit
2. Premium prompt appears with usage statistics
3. User can upgrade or dismiss
4. Subscription view shows available plans
5. Purchase completes with success feedback

### Subscription Management

- Users can restore purchases
- Subscription status syncs across devices
- Graceful handling of expired subscriptions
- Clear communication of limits and benefits

## Testing

### StoreKit Testing

1. Add `StoreKitConfiguration.storekit` to your Xcode project
2. Enable StoreKit testing in scheme settings
3. Test purchase flows in simulator
4. Verify subscription status updates

### Test Scenarios

- Purchase flow for each tier
- Restore purchases
- Subscription expiration
- Feature limit enforcement
- Upgrade/downgrade flows

## App Store Connect Setup

### Product Configuration

1. Create subscription groups in App Store Connect
2. Add products with correct identifiers
3. Set pricing and availability
4. Configure subscription terms

### Required Metadata

- Subscription group names
- Product descriptions
- Pricing information
- Terms of service
- Privacy policy

## Analytics and Monitoring

### Key Metrics

- Subscription conversion rate
- Feature usage by tier
- Upgrade/downgrade patterns
- Revenue per user
- Churn rate

### Implementation

```swift
// Track subscription events
Analytics.track("subscription_purchased", properties: [
    "tier": tier.rawValue,
    "price": product.price
])
```

## Security Considerations

- Server-side receipt validation
- Subscription status verification
- Fraud prevention measures
- Secure payment processing

## Compliance

### App Store Guidelines

- Clear subscription terms
- Easy cancellation process
- No misleading pricing
- Proper subscription management

### Privacy

- Minimal data collection
- Secure storage of subscription data
- User consent for data usage
- GDPR compliance

## Future Enhancements

### Planned Features

- Family sharing support
- Introductory offers
- Promotional pricing
- Enterprise subscriptions
- Custom subscription tiers

### Technical Improvements

- Server-side subscription validation
- Advanced analytics integration
- A/B testing for pricing
- Automated subscription management

## Support

For questions about the subscription system:

1. Check this documentation
2. Review the code comments
3. Test with StoreKit configuration
4. Contact the development team

## Changelog

### Version 1.0
- Initial subscription system implementation
- Three-tier pricing model
- StoreKit 2 integration
- Feature access control
- Premium prompts and upgrade flow
