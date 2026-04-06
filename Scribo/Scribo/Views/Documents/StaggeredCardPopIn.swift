import SwiftUI

// MARK: - Staggered card pop-in

struct StaggeredCardPopInModifier: ViewModifier {
    enum Style {
        /// Legacy: fade in + scale + offset (first paint only).
        case fadeAndScale
        /// No animation.
        case instant
        /// Quick scale pop, full opacity — no fade from invisible.
        case bounce
    }

    var delay: Double = 0
    var style: Style = .fadeAndScale
    @State private var appeared = false

    func body(content: Content) -> some View {
        switch style {
        case .instant:
            content
        case .bounce:
            content
                .scaleEffect(appeared ? 1 : 0.94)
                .onAppear {
                    guard !appeared else { return }
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.58).delay(delay)) {
                        appeared = true
                    }
                }
        case .fadeAndScale:
            content
                .scaleEffect(appeared ? 1 : 0.86)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .onAppear {
                    guard !appeared else { return }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.76).delay(delay)) {
                        appeared = true
                    }
                }
        }
    }
}

extension View {
    func staggeredCardPopIn(delay: Double = 0, style: StaggeredCardPopInModifier.Style = .fadeAndScale) -> some View {
        modifier(StaggeredCardPopInModifier(delay: delay, style: style))
    }
}
