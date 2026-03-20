import SwiftUI

struct ImageGalleryGridView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var showImageViewer = false
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Button(action: {
                            selectedIndex = index
                            showImageViewer = true
                        }) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipped()
                            .cornerRadius(12)
                            }
                        .accessibilityLabel("Image \(index + 1) of \(images.count)")
                        .accessibilityHint("Double tap to view full screen")
                    }
                }
                .padding()
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close gallery")
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .fullScreenCover(isPresented: $showImageViewer) {
                FullscreenImageViewer(
                    image: images[selectedIndex],
                    allImages: images,
                    currentIndex: selectedIndex,
                    isPresented: $showImageViewer
                )
            }
        }
    }
}
