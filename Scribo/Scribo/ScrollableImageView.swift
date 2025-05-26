import SwiftUI

struct ScrollableImageView: View {
    let image: Image
    let containerHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width

            ScrollView(.vertical, showsIndicators: false) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: containerWidth)
            }
            .frame(width: containerWidth, height: containerHeight)
            .clipped()
            .contentShape(Rectangle()) // Makes sure touch is caught only here
            .gesture(DragGesture()) // To avoid parent ScrollView stealing the drag
        }
        .frame(height: containerHeight)
    }
} 