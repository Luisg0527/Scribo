import SwiftUI

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let image: UIImage?
    let document: DocumentMessage?
    let isUser: Bool
    let timestamp: Date
    var isProcessing: Bool = false
    var error: String? = nil
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isProcessing == rhs.isProcessing &&
        lhs.error == rhs.error
    }
}

struct DocumentMessage: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: String
} 