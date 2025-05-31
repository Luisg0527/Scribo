import SwiftUI
import UIKit

struct DocumentPreview: View {
    let document: DocumentMessage
    
    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.blue)
            Text(document.name)
                .foregroundColor(.blue)
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(16)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .cornerRadius(12)
                } else if let imageUrl = message.imageUrl {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .cornerRadius(12)
                    } else if isLoading {
                        ProgressView()
                            .frame(width: 200, height: 200)
                    } else if loadError {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("Failed to load image")
                                .foregroundColor(.red)
                        }
                        .frame(width: 200, height: 200)
                    } else {
                        Color.clear
                            .frame(width: 200, height: 200)
                            .onAppear {
                                loadImage(from: imageUrl)
                            }
                    }
                }
                
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                if let document = message.document {
                    DocumentPreview(document: document)
                }
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    private func loadImage(from urlString: String) {
        isLoading = true
        loadError = false
        
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(urlString)
        
        if let data = try? Data(contentsOf: fileURL),
           let loadedImage = UIImage(data: data) {
            DispatchQueue.main.async {
                self.image = loadedImage
                self.isLoading = false
            }
        } else {
            DispatchQueue.main.async {
                self.loadError = true
                self.isLoading = false
            }
        }
    }
} 