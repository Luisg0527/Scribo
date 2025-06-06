import SwiftUI

enum FontManager {
    static func registerFonts() {
        // Register all Soleil font variants
        let fontNames = ["SoleilRegular", "SoleilBold", "SoleilLight", "SoleilBook"]
        
        for fontName in fontNames {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "otf") else {
                print("❌ Failed to find \(fontName) font file")
                continue
            }
            
            guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
                print("❌ Failed to load font data for \(fontName)")
                continue
            }
            
            guard let font = CGFont(fontDataProvider) else {
                print("❌ Failed to create font from data for \(fontName)")
                continue
            }
            
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                print("❌ Failed to register font \(fontName): \(error.debugDescription)")
            } else {
                print("✅ Successfully registered font: \(fontName)")
            }
        }
    }
}

extension Font {
    static func soleil(size: CGFloat) -> Font {
        return .custom("SoleilRegular", size: size)
    }
    
    static func soleilBold(size: CGFloat) -> Font {
        return .custom("SoleilBold", size: size)
    }
    
    static func soleilLight(size: CGFloat) -> Font {
        return .custom("SoleilLight", size: size)
    }
    
    static func soleilBook(size: CGFloat) -> Font {
        return .custom("SoleilBook", size: size)
    }
} 