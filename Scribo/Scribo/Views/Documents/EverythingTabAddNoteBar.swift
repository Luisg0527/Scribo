import SwiftUI

// MARK: - Everything tab: bottom “add note” bar (presented from ContentView for tab transitions)
struct EverythingTabAddNoteBar: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ADD A NEW NOTE")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.featureCalloutAccent)
                Text("Start typing here...")
                    .font(.body)
                    .foregroundColor(.featureCalloutText.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.white))
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.black)
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .black, location: 0.0),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 30)
                        }
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.top, 0)
        .padding(.bottom, -10)
    }
}
