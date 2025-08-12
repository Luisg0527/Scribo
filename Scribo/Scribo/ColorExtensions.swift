import SwiftUI

struct AppColors {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "1b1a21") : Color(hex: "F5F5F7")
    }
    
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2b2a31") : Color(hex: "FFFFFF")
    }
    
    static func headerBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2b2a31") : Color(hex: "F0F0F0")
    }
    
    static func accent1(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "fbfbfe") : Color(hex: "6A5ACD")
    }
    
    static func accent2(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3e3b47") : Color(hex: "E5E5EA")
    }
    
    static func text(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "fbfbfe") : Color(hex: "1A1B2E")
    }
    
    static func textSecondary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "fbfbfe").opacity(0.7) : Color(hex: "1A1B2E").opacity(0.7)
    }
    
    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.3)
    }
    
    static func featureCalloutBackground2(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "42414d") : Color.white
    }
    
    static func featureCalloutBackgroundWarm(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .light {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1b1a21"),
                    Color(hex: "1f1e26").opacity(0.8),
                    Color(hex: "1b1a21")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "F8F9FA"),
                    Color(hex: "F5F6F8").opacity(0.6),
                    Color(hex: "F8F9FA")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    static func featureCalloutBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2b2a31") : Color.white
    }
    
    static func featureCalloutBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .light {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1b1a21"),
                    Color(hex: "1e1d25").opacity(0.7),
                    Color(hex: "1b1a21")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "F8F9FA"),
                    Color(hex: "F6F7F9").opacity(0.5),
                    Color(hex: "F8F9FA")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    static func featureCalloutText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "fbfbfe") : Color(hex: "15141A")
    }
    
    static func featureCalloutBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3e3b47") : Color(hex: "CFCFD8")
    }
    
    static func featureCalloutAccent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "fbfbfe") : Color(hex: "0061E0")
    }
    
    static func featureCalloutButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "3e3b47") : Color(hex: "F0F0F4")
    }
    
    static func featureCalloutButtonText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "fbfbfe") : Color(hex: "15141A")
    }
    
    static func featureCalloutButtonHover(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "53525d") : Color(hex: "E0E0E6")
    }
    
    static func featureCalloutButtonActive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "53525d") : Color(hex: "CFCFD8")
    }
    
    static func featureCalloutPrimaryButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "00DDFF") : Color(hex: "0061E0")
    }
    
    static func featureCalloutPrimaryButtonText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "2B2A33") : Color(hex: "FBFBFE")
    }
    
    static func featureCalloutPrimaryButtonHover(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "80EBFF") : Color(hex: "0250BB")
    }
    
    static func featureCalloutPrimaryButtonActive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "AAF2FF") : Color(hex: "053E94")
    }
    
    static func featureCalloutLink(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "00DDFF") : Color(hex: "0061E0")
    }
    
    static func featureCalloutLinkHover(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "80EBFF") : Color(hex: "0250BB")
    }
    
    static func featureCalloutLinkActive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "AAF2FF") : Color(hex: "053E94")
    }
    
    static func featureCalloutSuccess(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "54FFBD") : Color(hex: "2AC3A2")
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
    
    static var featureCalloutBackground: Color {
        AppColors.featureCalloutBackground(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutBackground2: Color {
        AppColors.featureCalloutBackground2(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutText: Color {
        AppColors.featureCalloutText(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutBorder: Color {
        AppColors.featureCalloutBorder(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutAccent: Color {
        AppColors.featureCalloutAccent(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutButtonBackground: Color {
        AppColors.featureCalloutButtonBackground(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutButtonText: Color {
        AppColors.featureCalloutButtonText(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutButtonHover: Color {
        AppColors.featureCalloutButtonHover(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutButtonActive: Color {
        AppColors.featureCalloutButtonActive(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutPrimaryButtonBackground: Color {
        AppColors.featureCalloutPrimaryButtonBackground(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutPrimaryButtonText: Color {
        AppColors.featureCalloutPrimaryButtonText(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutPrimaryButtonHover: Color {
        AppColors.featureCalloutPrimaryButtonHover(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutPrimaryButtonActive: Color {
        AppColors.featureCalloutPrimaryButtonActive(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutLink: Color {
        AppColors.featureCalloutLink(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutLinkHover: Color {
        AppColors.featureCalloutLinkHover(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutLinkActive: Color {
        AppColors.featureCalloutLinkActive(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
    }
    
    static var featureCalloutSuccess: Color {
        AppColors.featureCalloutSuccess(for: UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
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
