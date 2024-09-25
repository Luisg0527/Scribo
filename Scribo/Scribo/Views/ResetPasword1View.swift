//
//  ResetPasword1View.swift
//  Scribo
//
//  Created by Luis Garza on 25/09/24.
//

import SwiftUI

struct ResetPasword1View: View {
    var body: some View {
        ScrollView {
            VStack {
                AsyncImage(url: URL(string: "https://cdn.builder.io/api/v1/image/assets/TEMP/9065ab1f2acd1aa6ce29a61999895e25156663e5482bd2366629889e16674995?placeholderIfAbsent=true&apiKey=33b36dbf34f847e9a4c740eb95e9e6ec&format=webp")) { image in
                    image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                } placeholder: {
                    ProgressView()
                }
                .padding(.top, 62)
                .padding(.bottom, 118)
            }
        }
        .background(Color.black)
    }
}

#Preview {
    ResetPasword1View()
}
