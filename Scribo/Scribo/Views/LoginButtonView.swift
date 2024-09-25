import SwiftUI

struct LoginButtonView: View {
    let icon: String
    let text: String
    let backgroundColor: Color
    let textColor: Color
    
    var body: some View {
        Button(action: {
            // Handle button action
        }) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: "\(icon)&format=webp")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 24, height: 24)
                
                Text(text)
                    .foregroundColor(textColor)
                    .font(.system(size: 20, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
        }
        .accessibilityLabel(text)
    }
}

struct LoginButtonView_Previews: PreviewProvider {
    static var previews: some View {
        LoginButtonView(icon: "https://cdn.builder.io/api/v1/image/assets/TEMP/2f35c884d581946cddfbdf866235b0be478871f51e095533643cfb60e01a029c?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec", text: "Continue with Apple", backgroundColor: .white, textColor: .black)
    }
}
