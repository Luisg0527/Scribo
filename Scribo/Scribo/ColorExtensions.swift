import SwiftUI

struct AppColors {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1A1B2E") : Color(hex: "F5F5F7")
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "25273D") : Color(hex: "FFFFFF")
    }
    
    static func headerBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2D2F4A") : Color(hex: "F0F0F0")
    }
    
    static func accent1(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "E6E4F0") : Color(hex: "6A5ACD")
    }
    
    static func accent2(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2D2F4A") : Color(hex: "E5E5EA")
    }
    
    static func text(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color(hex: "1A1B2E")
    }
    
    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color(hex: "1A1B2E").opacity(0.7)
    }
    
    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color(hex: "FF3366").opacity(0.15)
    }
}

extension Color {
    static var appBackground: Color {
        AppColors.background(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appCardBackground: Color {
        AppColors.cardBackground(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appHeaderBackground: Color {
        AppColors.headerBackground(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appAccent1: Color {
        AppColors.accent1(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appAccent2: Color {
        AppColors.accent2(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appText: Color {
        AppColors.text(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appTextSecondary: Color {
        AppColors.textSecondary(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var appShadow: Color {
        AppColors.shadow(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 