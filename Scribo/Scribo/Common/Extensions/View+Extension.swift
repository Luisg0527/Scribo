import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    func defaultShadow() -> some View {
        shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func defaultBackground() -> some View {
        background(Constants.Colors.appCardBackground)
    }
    
    func defaultPadding() -> some View {
        padding(Constants.Layout.defaultPadding)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
} 