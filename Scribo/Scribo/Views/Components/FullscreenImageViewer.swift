import SwiftUI

struct FullscreenImageViewer: View {
    let image: UIImage
    let allImages: [UIImage]
    let currentIndex: Int
    @Binding var isPresented: Bool
    /// When set with `zoomTransitionSourceID`, enables the system zoom presentation transition (iOS 18+).
    var transitionNamespace: Namespace.ID? = nil
    var zoomTransitionSourceID: Int? = nil
    @State private var showOverlay = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            zoomableScrollContent

            if showOverlay {
                VStack {
                    HStack {
                        Button("Done") {
                            dismiss()
                        }
                        .padding()
                        .foregroundColor(.white)
                        .accessibilityLabel("Close image viewer")

                        Spacer()

                        Button {
                            shareImage(image)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .padding()
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Share image")
                        .accessibilityHint("Double tap to share this image")
                    }
                    .background(Color.black.opacity(0.6))
                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var zoomableScrollContent: some View {
        if let ns = transitionNamespace, let sid = zoomTransitionSourceID {
            zoomScrollBase
                .navigationTransition(.zoom(sourceID: sid, in: ns))
        } else {
            zoomScrollBase
        }
    }

    private var zoomScrollBase: some View {
        ZoomableScrollView {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Image \(currentIndex + 1) of \(allImages.count)")
        }
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showOverlay.toggle()
            }
        }
    }

    private func shareImage(_ image: UIImage) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = window
            popoverController.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true)
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.maximumZoomScale = 5.0
        scroll.minimumZoomScale = 1.0
        scroll.bouncesZoom = true
        scroll.delegate = context.coordinator

        let hosted = UIHostingController(rootView: content)
        hosted.view.translatesAutoresizingMaskIntoConstraints = false
        hosted.view.backgroundColor = .clear

        scroll.addSubview(hosted.view)

        NSLayoutConstraint.activate([
            hosted.view.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            hosted.view.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            hosted.view.topAnchor.constraint(equalTo: scroll.topAnchor),
            hosted.view.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            hosted.view.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            hosted.view.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.subviews.first
        }
    }
}
