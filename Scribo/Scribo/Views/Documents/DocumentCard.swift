import SwiftUI

struct DocumentCard: View {
    let document: DocumentItem
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = document.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 320)
                    .clipped()
                    .cornerRadius(12)
            } else {
                if let preview = document.previewText,
                   !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(preview)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180, alignment: .topLeading)
                        .padding(14)
                        .background(Color(hex: "C6C6CB"))
                        .cornerRadius(12)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.featureCalloutBackground2.opacity(1.2))
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
