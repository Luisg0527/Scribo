import SwiftUI

enum Constants {
    enum Colors {
        static let appBackground = Color(UIColor.systemBackground)
        static let appCardBackground = Color(UIColor.secondarySystemBackground)
        static let appHeaderBackground = Color(UIColor.tertiarySystemBackground)
        static let appText = Color(UIColor.label)
        static let appAccent = Color.blue
    }
    
    enum Animation {
        static let defaultDuration: Double = 0.3
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: defaultDuration)
    }
    
    enum Layout {
        static let defaultPadding: CGFloat = 16
        static let defaultCornerRadius: CGFloat = 12
        static let defaultSpacing: CGFloat = 8
    }
} 