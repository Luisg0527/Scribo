import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isAnimating = false
    @State private var animateBackground = false

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.95, blue: 0.97),
                    isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.3) : Color(red: 0.9, green: 0.9, blue: 0.95)
                ]),
                startPoint: animateBackground ? .topLeading : .bottomLeading,
                endPoint: animateBackground ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateBackground)

            // Logo and Title
                Image("ScriboIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
            animateBackground = true
        }
    }
}
