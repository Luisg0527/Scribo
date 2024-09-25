import SwiftUI

struct LoginView: View {
    var body: some View {
        
        ScrollView {
            VStack(spacing: 0) {
                
                Spacer().frame(height: 201)
                
                AsyncImage(url: URL(string: "https://cdn.builder.io/api/v1/image/assets/TEMP/b9262a23de5880425c31b42fbf1e9ea4907de7715582c9eb336689586921692f?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 140, height: 140)
                
                Spacer().frame(height: 135)
                
                VStack(spacing: 11) {
                    LoginButtonView(icon: "https://cdn.builder.io/api/v1/image/assets/TEMP/2f35c884d581946cddfbdf866235b0be478871f51e095533643cfb60e01a029c?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp", text: "Continue with Apple", backgroundColor: Color.white, textColor: Color.black)
                    LoginButtonView(icon: "https://cdn.builder.io/api/v1/image/assets/TEMP/a1263bc057d31b849e43a68f2b89b9da2a96cdc8f39d55b87688eaec2533078f?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp", text: "Continue with Google", backgroundColor: Color(red: 86/255, green: 88/255, blue: 92/255, opacity: 0.87), textColor: Color.white)
                    LoginButtonView(icon: "https://cdn.builder.io/api/v1/image/assets/TEMP/106938a96058811ee6707c563df3b099af471676be8bf29e8058dc292a5c229e?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp", text: "Sign up with email", backgroundColor: Color(red: 86/255, green: 88/255, blue: 92/255, opacity: 0.87), textColor: Color.white)
                    
                    // Login Button
                    Button(action: {
                        // Handle login action
                    }) {
                        Text("Log in")
                            .font(.system(size: 20, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 48/255, green: 50/255, blue: 64/255))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 143/255, green: 143/255, blue: 143/255), lineWidth: 2)
                            )
                    }
                    .accessibilityLabel("Log in")
                    
                    // Create an account button
                    Button(action: {
                        // Handle create account action
                    }) {
                        Text("Create an account")
                            .foregroundColor(Color(white: 1, opacity: 0.86))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.top, 10)
                    .accessibilityLabel("Create an account")
                    
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color.black)
                        .frame(width: 139, height: 5)
                        .padding(.top, 25)
                }
                .padding(.horizontal, 23)
                .padding(.vertical, 25)
                .background(Color.black)
                .cornerRadius(20)
            }
            .frame(maxWidth: 480)
            .padding(.top, 40)
        }
        //.background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#303240"),Color(hex: "#46495D"), Color(hex: "#60647F")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .edgesIgnoringSafeArea(.all)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

extension Color {
    init(hex: String) {
        var cleanHexCode = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHexCode = cleanHexCode.replacingOccurrences(of: "#", with: "")
        
        // Ensure the hex string is valid (6 or 8 characters)
        guard cleanHexCode.count == 6 || cleanHexCode.count == 8 else {
            self = Color.gray // Fallback to gray if invalid
            return
        }
        
        var rgb: UInt64 = 0
        Scanner(string: cleanHexCode).scanHexInt64(&rgb)
        
        let redValue = Double((rgb >> 16) & 0xFF) / 255.0
        let greenValue = Double((rgb >> 8) & 0xFF) / 255.0
        let blueValue = Double(rgb & 0xFF) / 255.0
        
        // Optional: Add alpha (opacity) handling for 8-character hex codes
        let alphaValue = cleanHexCode.count == 8
            ? Double((rgb >> 24) & 0xFF) / 255.0
            : 1.0
        
        // SwiftUI uses `opacity` parameter for alpha
        self.init(red: redValue, green: greenValue, blue: blueValue, opacity: alphaValue)
    }
}
