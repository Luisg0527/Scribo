//
//  ResetPaswordView2.swift
//  Scribo
//
//  Created by Luis Garza on 25/09/24.
//

import SwiftUI

struct ResetPaswordView2: View {
    @State private var verificationCode: String = ""
    
    
    var body: some View {
        ScrollView {
            VStack {
                AsyncImage(url: URL(string: "https://cdn.builder.io/api/v1/image/assets/TEMP/9065ab1f2acd1aa6ce29a61999895e25156663e5482bd2366629889e16674995?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp")) {
                    image in
                    image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                }
                placeholder: {
                    ProgressView()
                }
                .padding(.top, 44)
                .padding(.bottom, 92)
                
                Text("Verify your identity")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.bottom, 18)
                
                Text("We will send you an email that wil allow you to reset your password. Check your inbox and enter the code below")
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black.opacity(0.86))
                    .frame(width: 356, height: 68, alignment: .center)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter your code")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                    
                    TextField("", text: $verificationCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(height: 48)
                        .accessibility(label: Text("Verification code input"))
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                
                HStack{
                    Text("Didn’t recieve a code?")
                        .foregroundColor(Color.black.opacity(0.86))
                        .font(.system(size: 15))
                    
                    Button("Try Again") {
                        // Re-send code
                    }
                    .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                    .font(.system(size: 15))
                    .padding(.vertical, 5)
                }
                NavigationLink(destination: ResetPaswordView3()) {
                    Text("Continue")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(red: 48/255, green: 50/255, blue: 64/255))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 277)
            }
        }
    }
}

#Preview {
    ResetPaswordView2()
}
