//
//  ResetPasword1View.swift
//  Scribo
//
//  Created by Luis Garza on 25/09/24.
//

import SwiftUI

struct ResetPaswordView1: View {
    @State private var rpEmail: String = ""
    
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
                .padding(.top, 62)
                .padding(.bottom, 110)
                
                Text("Reset Your Password")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 18)
                
                VStack {
                    TextField("Email address*", text: $rpEmail)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                        .accessibility(label: Text("Email address"))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 85)
                
                NavigationLink(destination: ResetPaswordView2()) {
                    Text("Continue")
                        .foregroundColor(.white)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 48/255, green: 50/255, blue: 64/255))
                        .cornerRadius(14)
                        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 4)
                        
                }
                .padding(.horizontal)
                
                /*HStack {
                    Text("Already have an account?")
                        .foregroundColor(Color.white.opacity(0.86))
                        .font(.system(size: 15))
                    
                    NavigationLink(destination: LoginView()) {
                        Text("Log in")
                            .foregroundColor(Color(red: 124/255, green: 207/255, blue: 255/255))
                            .font(.system(size: 15))
                    }
                }
                .padding(.top, 4)*/
            }
        }
        .background(Color.black)
    }
}

#Preview {
    ResetPaswordView1()
}
