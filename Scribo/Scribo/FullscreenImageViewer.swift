import SwiftUI

struct FullscreenImageViewer: View {
    let image: UIImage
    let allImages: [UIImage]
    let currentIndex: Int
    @Binding var isPresented: Bool
    @State private var showOverlay = true
    @State private var isShowingGallery = false
    @State private var selectedIndex: Int = 0

    var body: some View {
        ZStack {
            ZoomableScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation { showOverlay.toggle() }
            }

            if showOverlay {
                VStack {
                    HStack {
                        Button("Done") {
                            isPresented = false
                        }
                        .padding()
                        .foregroundColor(.white)

                        Spacer()

                        Button {
                            shareImage(image)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .padding()
                                .foregroundColor(.white)
                        }

                        Button {
                            selectedIndex = currentIndex
                            isShowingGallery = true
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.title2)
                                .padding(.trailing)
                                .foregroundColor(.white)
                        }
                    }
                    .background(Color.black.opacity(0.6))
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $isShowingGallery) {
            ImageGalleryGridView(
                images: allImages,
                selectedIndex: $selectedIndex,
                isPresented: $isShowingGallery
            )
        }
    }

    private func shareImage(_ image: UIImage) {
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
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
