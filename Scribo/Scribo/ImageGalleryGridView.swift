import SwiftUI

struct ImageGalleryGridView: View {
    let images: [UIImage]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var showImageViewer = false

    private let columns = [
        GridItem(.fixed(160), spacing: 12),
        GridItem(.fixed(160), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipped()
                            .cornerRadius(12)
                            .onTapGesture {
                                selectedIndex = index
                                showImageViewer = true
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
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
