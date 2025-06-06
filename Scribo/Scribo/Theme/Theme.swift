import SwiftUI

struct Theme {
    // Colors
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let background = Color("Background")
    static let text = Color("Text")
    
    // Fonts
    static let soleil = Font.soleil(size: 16)
    static let soleilBold = Font.soleilBold(size: 16)
    static let soleilLight = Font.soleilLight(size: 16)
    
    static let soleilTitle = Font.soleilBold(size: 24)
    static let soleilHeadline = Font.soleilBold(size: 20)
    static let soleilSubheadline = Font.soleil(size: 18)
    static let soleilBody = Font.soleil(size: 16)
    static let soleilCaption = Font.soleilLight(size: 14)
    static let soleilSmall = Font.soleilLight(size: 12)
    
    // Spacing
    static let spacing: CGFloat = 16
    static let cornerRadius: CGFloat = 12
    
    // Animation
    static let animation = Animation.easeInOut(duration: 0.3)
} 