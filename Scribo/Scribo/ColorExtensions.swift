import SwiftUI

extension Color {
    static let appBackground = Color(hex: "20212A")      // Darkest background
    static let appCardBackground = Color(hex: "2D2F3C")  // Card background
    static let appHeaderBackground = Color(hex: "373A4A") // Header background
    static let appAccent1 = Color.white                   // Primary accent (white)
    static let appAccent2 = Color(hex: "303240")         // Secondary accent (original)
    static let appText = Color.white                      // Text color
    static let appTextSecondary = Color.white.opacity(0.7) // Secondary text
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