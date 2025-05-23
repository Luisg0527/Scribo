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

enum ClassificationError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case serverError(String)
}

class TextClassificationService {
    private let serverURL: String
    private let apiKey: String
    
    init(serverURL: String, apiKey: String) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }
    
    func classifyText(_ text: String) async throws -> TextClassificationResponse {
        guard let url = URL(string: serverURL) else {
            throw ClassificationError.invalidURL
        }
        
        let payload = ClassificationRequest(
            text: text,
            labels: ["topic", "subtopic", "note_name"]
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
            print("Request payload: \(String(data: request.httpBody!, encoding: .utf8) ?? "none")")
        } catch {
            print("Error encoding request: \(error)")
            throw ClassificationError.decodingError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassificationError.invalidResponse(0)
            }
            
            print("Response status code: \(httpResponse.statusCode)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "none")")
            
            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(TextClassificationResponse.self, from: data)
                    return result
                } catch {
                    print("Decoding error: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "none")")
                    throw ClassificationError.decodingError(error)
                }
            case 401:
                throw ClassificationError.serverError("Unauthorized: Invalid API key")
            case 403:
                throw ClassificationError.serverError("Forbidden: Access denied")
            case 404:
                throw ClassificationError.serverError("Not found: The requested resource does not exist")
            case 422:
                throw ClassificationError.serverError("Invalid request format: \(String(data: data, encoding: .utf8) ?? "unknown error")")
            case 500:
                throw ClassificationError.serverError("Internal server error")
            default:
                throw ClassificationError.invalidResponse(httpResponse.statusCode)
            }
        } catch let error as ClassificationError {
            throw error
        } catch {
            throw ClassificationError.networkError(error)
        }
    }
} 