import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    let onImageTap: (UIImage) -> Void
    let onDocumentTap: (DocumentMessage) -> Void
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .cornerRadius(12)
                        .onTapGesture {
                            onImageTap(image)
                        }
                }
                
                if let document = message.document {
                    DocumentPreviewView(document: document)
                        .onTapGesture {
                            onDocumentTap(document)
                        }
                }
                
                if !message.content.isEmpty {
                    Text(message.content)
                        .padding(12)
                        .background(message.isUser ? Color.blue : Color(.systemGray6))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(12)
                }
                
                if message.isProcessing {
                    ProgressView()
                        .padding(.top, 4)
                }
                
                if let error = message.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct DocumentPreviewView: View {
    let document: DocumentMessage
    
    var body: some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.blue)
            Text(document.name)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
} 