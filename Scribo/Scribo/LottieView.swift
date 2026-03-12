import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var playSpeed: CGFloat = 1.0
    
    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: name)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.animationSpeed = playSpeed
        animationView.play()
        return animationView
    }
    
    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.loopMode = loopMode
        uiView.animationSpeed = playSpeed
        if !uiView.isAnimationPlaying {
            uiView.play()
        }
    }
}

