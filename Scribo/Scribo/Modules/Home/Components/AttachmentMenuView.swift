import SwiftUI
import PhotosUI

struct AttachmentMenuView: View {
    @Binding var isShowing: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var selectedDocument: URL?
    @Binding var isDocumentPickerPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 24))
                        Text("Photo")
                            .font(.caption)
                    }
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: {
                    isDocumentPickerPresented = true
                }) {
                    VStack {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 24))
                        Text("Document")
                            .font(.caption)
                    }
                    .foregroundColor(.appAccent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.appHeaderBackground)
        }
    }
} 