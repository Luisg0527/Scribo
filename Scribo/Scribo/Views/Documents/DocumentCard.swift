import SwiftUI

struct DocumentCard: View {
    /// Matches text-preview card body height so image notes align in the two-column grid.
    private static let gridMediaHeight: CGFloat = 180

    let document: DocumentItem
    let onDelete: () -> Void

    private var trimmedTitle: String {
        document.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var typeIndicatorSymbol: String {
        switch document.type {
        case .scanned:
            return "doc.viewfinder"
        case .document:
            return "doc.text.fill"
        case .camera:
            return "camera.fill"
        case .photo:
            return document.siblingImageCount > 1 ? "photo.stack.fill" : "photo.fill"
        }
    }

    /// High-contrast pill behind the type glyph (works on photos and pale previews).
    private var typeIndicatorBadge: some View {
        Image(systemName: typeIndicatorSymbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0.5)
            .padding(6)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = document.image {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.gridMediaHeight)
                        .clipped()
                    typeIndicatorBadge
                        .padding(8)
                }
                .cornerRadius(12)
                .clipped()
            } else {
                if let preview = document.previewText,
                   !preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ZStack(alignment: .topTrailing) {
                        Text(preview)
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                            .lineLimit(8)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: Self.gridMediaHeight, maxHeight: Self.gridMediaHeight, alignment: .topLeading)
                            .padding(14)
                            .background(Color.featureCalloutBackground)
                        typeIndicatorBadge
                            .padding(8)
                    }
                    .cornerRadius(12)
                    .clipped()
                } else {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.featureCalloutBackground)
                            .frame(height: Self.gridMediaHeight)
                        typeIndicatorBadge
                            .padding(8)
                    }
                    .clipped()
                }
            }

            if !trimmedTitle.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trimmedTitle)
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
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
