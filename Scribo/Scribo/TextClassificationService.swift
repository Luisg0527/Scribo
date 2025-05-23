import Foundation

struct ClassificationRequest: Codable {
    let text: String
    let labels: [String]
}

struct ClassificationResponse: Codable {
    let topic: String
    let subtopic: String?
    let note_name: String
    let raw_scores: [String: Float]
}

class TextClassificationService {
    private let serverURL: String
    private let apiKey: String
    
    init(serverURL: String = "http://YOUR_SERVER_IP:8000/classify", apiKey: String = "my-secret-key") {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }
    
    func classifyText(_ text: String) async throws -> ClassificationResponse {
        guard let url = URL(string: serverURL) else {
            throw NSError(domain: "TextClassificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let payload = ClassificationRequest(
            text: text,
            labels: ["biology", "technology", "politics", "sports", "education"]
        )
        
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "TextClassificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
        }
        
        return try JSONDecoder().decode(ClassificationResponse.self, from: data)
    }
} 