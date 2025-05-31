import Foundation
import UIKit

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let image: UIImage?
    let document: DocumentMessage?
    let isUser: Bool
    let timestamp: Date
    var isProcessing: Bool = false
    var error: String? = nil
    var chatId: UUID?
    var imageUrl: String?
    var documentUrl: String?
    var documentName: String?
    var documentType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isUser = "is_user"
        case timestamp = "created_at"
        case isProcessing
        case error
        case chatId = "chat_id"
        case imageUrl = "image_url"
        case documentUrl = "document_url"
        case documentName = "document_name"
        case documentType = "document_type"
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isUser == rhs.isUser &&
        lhs.timestamp == rhs.timestamp &&
        lhs.isProcessing == rhs.isProcessing &&
        lhs.error == rhs.error &&
        lhs.chatId == rhs.chatId &&
        lhs.imageUrl == rhs.imageUrl &&
        lhs.documentUrl == rhs.documentUrl &&
        lhs.documentName == rhs.documentName &&
        lhs.documentType == rhs.documentType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        
        // Decode timestamp from ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampString = try container.decode(String.self, forKey: .timestamp)
        guard let timestamp = dateFormatter.date(from: timestampString) else {
            throw DecodingError.dataCorruptedError(forKey: .timestamp, in: container, debugDescription: "Date string does not match format")
        }
        self.timestamp = timestamp
        
        isProcessing = try container.decodeIfPresent(Bool.self, forKey: .isProcessing) ?? false
        error = try container.decodeIfPresent(String.self, forKey: .error)
        chatId = try container.decodeIfPresent(UUID.self, forKey: .chatId)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        documentUrl = try container.decodeIfPresent(String.self, forKey: .documentUrl)
        documentName = try container.decodeIfPresent(String.self, forKey: .documentName)
        documentType = try container.decodeIfPresent(String.self, forKey: .documentType)
        
        // Load image if URL exists
        if let imageUrl = imageUrl {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(imageUrl)
            if let data = try? Data(contentsOf: fileURL),
               let uiImage = UIImage(data: data) {
                image = uiImage
            } else {
                image = nil
            }
        } else {
            image = nil
        }
        
        // Create document message if URL exists
        if let documentUrl = documentUrl,
           let url = URL(string: documentUrl),
           let documentName = documentName,
           let documentType = documentType {
            document = DocumentMessage(url: url, name: documentName, type: documentType)
        } else {
            document = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(isUser, forKey: .isUser)
        
        // Encode timestamp as ISO8601 string
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: timestamp), forKey: .timestamp)
        
        try container.encode(isProcessing, forKey: .isProcessing)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(chatId, forKey: .chatId)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(documentUrl, forKey: .documentUrl)
        try container.encodeIfPresent(documentName, forKey: .documentName)
        try container.encodeIfPresent(documentType, forKey: .documentType)
    }
    
    init(content: String, image: UIImage? = nil, document: DocumentMessage? = nil, isUser: Bool, timestamp: Date, isProcessing: Bool = false, error: String? = nil, chatId: UUID? = nil) {
        self.id = UUID()
        self.content = content
        self.image = image
        self.document = document
        self.isUser = isUser
        self.timestamp = timestamp
        self.isProcessing = isProcessing
        self.error = error
        self.chatId = chatId
        self.documentName = document?.name
        self.documentType = document?.type
        
        // Save image if provided
        if let image = image {
            let fileName = "\(id).jpg"
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: fileURL)
                self.imageUrl = fileName
            } else {
                self.imageUrl = nil
            }
        } else {
            self.imageUrl = nil
        }
        
        // Set document URL if provided
        self.documentUrl = document?.url.absoluteString
    }
} 