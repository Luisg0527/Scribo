import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AsyncImage(url: URL(string: "https://cdn.builder.io/api/v1/image/assets/TEMP/9065ab1f2acd1aa6ce29a61999895e25156663e5482bd2366629889e16674995?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp")) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                } placeholder: {
                    ProgressView()
                }
                .padding(.top, 62)
                .padding(.bottom, 118)
                
                Text("Welcome back")
                    .font(.system(size: 32, weight: .bold))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 18)
                
                VStack(spacing: 10) {
                    TextField("Email address*", text: $email)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                        .accessibility(label: Text("Email address"))
                    
                    HStack {
                        SecureField("Password*", text: $password)
                        AsyncImage(url: URL(string: "https://cdn.builder.io/api/v1/image/assets/TEMP/41e48adbb8d435771dea69100696633aff88d278f26ae9fa8a2e77f00d2300d8?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp")) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                }
                .padding(.horizontal, 18)
                
                HStack{
                    NavigationLink(destination: ResetPasword1View()) {
                        Text("Forgot password?")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255, opacity: 0.86))
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .padding(.bottom, 28)
                
                
                Button(action: {
                    // Handle login
                }) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 70)
                        .background(Color(red: 48/255, green: 50/255, blue: 64/255))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                }
                
                HStack{
                    Text("Don't have an account? ")
                        .foregroundColor(Color.white.opacity(0.86))
                        .font(.system(size: 15)) +
                    Text("Sign up")
                        .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                        .font(.system(size: 15))
                }
                .padding(.top)
                
                VStack {
                    HStack {
                        Button(action: {
                            // Handle Terms of Use
                        }) {
                            Text("Terms of Use")
                                .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                                .font(.system(size: 15))
                        }
                        Text("|")
                            .foregroundColor(Color.white.opacity(0.86))
                            .font(.system(size: 15))
                        Button(action: {
                            // Handle Privacy Policy
                        }) {
                            Text("Privacy Policy")
                                .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                                .font(.system(size: 15))
                        }
                    }
                }
                .padding(.top, 170)
            }
        }
        .background(Color.black)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
