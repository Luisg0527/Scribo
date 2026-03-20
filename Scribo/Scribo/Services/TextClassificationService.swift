import Foundation

struct ClassificationRequest: Codable {
    let text: String
    let labels: [String]
}

struct ClassificationResponse: Codable {
    let topic: String
    let subtopic: String?
    let note_name: String
    let raw_scores: [String: Double]
}

enum ClassificationError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case serverError(String)
}

class TextClassificationService {
    // Configuration
    static let serverURL = ProcessInfo.processInfo.environment["CLASSIFICATION_SERVER_URL"] ?? "http://192.168.68.120:8000/classify"
    static let apiKey = ProcessInfo.processInfo.environment["CLASSIFICATION_API_KEY"] ?? "dev-secret-12345"

    private let serverURL: String
    private let apiKey: String

    init(serverURL: String = TextClassificationService.serverURL,
         apiKey: String = TextClassificationService.apiKey) {
        self.serverURL = serverURL
        self.apiKey = apiKey
    }

    func classifyText(_ text: String) async throws -> TextClassificationResponse {
        print("Attempting to connect to server at: \(serverURL)")
        guard let url = URL(string: serverURL) else {
            print("Invalid URL: \(serverURL)")
            throw ClassificationError.invalidURL
        }

        // Preprocess text to improve classification
        let preprocessedText = preprocessText(text)

        let payload = ClassificationRequest(
            text: preprocessedText,
            labels: ClassificationLabels.allLabels
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            print("Request payload: \(String(data: request.httpBody!, encoding: .utf8) ?? "none")")
            print("Request headers: \(request.allHTTPHeaderFields ?? [:])")
        } catch {
            print("Error encoding request: \(error)")
            throw ClassificationError.decodingError(error)
        }

        do {
            print("Sending request to server...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("Received response from server")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type: \(type(of: response))")
                throw ClassificationError.invalidResponse(0)
            }

            print("Response status code: \(httpResponse.statusCode)")
            print("Response headers: \(httpResponse.allHeaderFields)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "none")")

            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(TextClassificationResponse.self, from: data)

                    // Post-process classification results
                    let processedResult = postProcessClassification(result)
                    return processedResult
                } catch {
                    print("Decoding error: \(error)")
                    print("Response data: \(String(data: data, encoding: .utf8) ?? "none")")
                    throw ClassificationError.decodingError(error)
                }
            case 401:
                print("Unauthorized: Invalid API key")
                throw ClassificationError.serverError("Unauthorized: Invalid API key")
            case 403:
                print("Forbidden: Access denied")
                throw ClassificationError.serverError("Forbidden: Access denied")
            case 404:
                print("Not found: The requested resource does not exist")
                throw ClassificationError.serverError("Not found: The requested resource does not exist")
            case 422:
                print("Invalid request format: \(String(data: data, encoding: .utf8) ?? "unknown error")")
                throw ClassificationError.serverError("Invalid request format: \(String(data: data, encoding: .utf8) ?? "unknown error")")
            case 500:
                print("Internal server error")
                throw ClassificationError.serverError("Internal server error")
            default:
                print("Unexpected status code: \(httpResponse.statusCode)")
                throw ClassificationError.invalidResponse(httpResponse.statusCode)
            }
        } catch let error as ClassificationError {
            print("Classification error: \(error)")
            throw error
        } catch {
            print("Network error: \(error)")
            throw ClassificationError.networkError(error)
        }
    }

    private func preprocessText(_ text: String) -> String {
        // Remove extra whitespace
        let cleanedText = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common technical terms that might bias classification
        let technicalTerms = ["swift", "swiftui", "ios", "xcode", "code", "programming", "developer"]
        var processedText = cleanedText
        for term in technicalTerms {
            processedText = processedText.replacingOccurrences(of: term, with: "", options: [.caseInsensitive])
        }

        return processedText
    }

    private func postProcessClassification(_ result: TextClassificationResponse) -> TextClassificationResponse {
        // If the top classification is Language/Translation/Speaking, check if there's a better match
        if result.topic == "Language" || result.subtopic == "Translation" || result.subtopic == "Speaking" {
            // Look for other high-scoring categories
            let sortedScores = result.raw_scores.sorted { $0.value > $1.value }
            if sortedScores.count > 1 {
                let secondBest = sortedScores[1]
                // If second best score is close to the best score (within 20%), use it instead
                if secondBest.value > sortedScores[0].value * 0.8 {
                    return TextClassificationResponse(
                        topic: secondBest.key,
                        subtopic: result.subtopic,
                        note_name: result.note_name,
                        raw_scores: result.raw_scores
                    )
                }
            }
        }
        return result
    }

    static func generateNoteName(from text: String, maxWords: Int = 5) -> String {
        // Remove special characters and extra whitespace
        let cleanText = text.replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Split into words and filter out common words
        let words = cleanText.components(separatedBy: " ")
        let commonWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "with", "by", "about", "as", "of", "from"])
        let filteredWords = words.filter { !commonWords.contains($0.lowercased()) }

        // Take first maxWords and capitalize each
        let selectedWords = Array(filteredWords.prefix(maxWords))
        let capitalizedWords = selectedWords.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }

        // Join with spaces
        return capitalizedWords.joined(separator: " ")
    }
}
