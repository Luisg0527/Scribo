import Foundation
import Supabase

// MARK: - Message Data Structure
struct ChatMessageData: Encodable {
    let chat_id: UUID
    let content: String
    let is_user: Bool
    let image_url: String?
    let document_url: String?
    let document_name: String?
    let document_type: String?
}

class ChatManager: ObservableObject {
    private let supabase = SupabaseConfig.shared.client
    
    // MARK: - Chat Operations
    
    func createChat(title: String) async throws -> Chat {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let response = try await supabase
            .from("chats")
            .insert([
                "title": title,
                "user_id": userId.uuidString
            ])
            .select("""
                id,
                title,
                user_id,
                created_at,
                updated_at,
                chat_messages (
                    id,
                    content,
                    is_user,
                    created_at,
                    image_url,
                    document_url,
                    document_name,
                    document_type
                )
            """)
            .single()
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Chat.self, from: response.data)
    }
    
    func getChats() async throws -> [Chat] {
        let response = try await supabase
            .from("chats")
            .select("""
                *,
                chat_messages (
                    id,
                    content,
                    is_user,
                    created_at,
                    image_url,
                    document_url,
                    document_name,
                    document_type
                )
            """)
            .order("updated_at", ascending: false)
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Chat].self, from: response.data)
    }
    
    func updateChat(_ chat: Chat) async throws {
        try await supabase
            .from("chats")
            .update([
                "title": chat.title,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: chat.id)
            .execute()
    }
    
    func deleteChat(_ chatId: UUID) async throws {
        do {
            try await supabase
                .from("chats")
                .delete()
                .eq("id", value: chatId)
                .execute()
        } catch {
            print("❌ Error during chat deletion process:")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            print("❌ Full error: \(error)")
            throw error
        }
    }
    
    // MARK: - Message Operations
    
    func addMessage(_ message: ChatMessage, to chatId: UUID) async throws {
        let messageData = ChatMessageData(
            chat_id: chatId,
            content: message.content,
            is_user: message.isUser,
            image_url: message.image != nil ? "\(message.id).jpg" : nil,
            document_url: message.document?.url.absoluteString,
            document_name: message.document?.name,
            document_type: message.document?.type
        )
        
        try await supabase
            .from("chat_messages")
            .insert(messageData)
            .execute()
        
        // Update chat's updated_at timestamp
        try await updateChatTimestamp(chatId)
    }
    
    private func updateChatTimestamp(_ chatId: UUID) async throws {
        try await supabase
            .from("chats")
            .update([
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: chatId)
            .execute()
    }
    
    func getMessages(for chatId: UUID) async throws -> [ChatMessage] {
        let response = try await supabase
            .from("chat_messages")
            .select()
            .eq("chat_id", value: chatId)
            .order("created_at", ascending: true)
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ChatMessage].self, from: response.data)
    }
} 