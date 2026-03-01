import Foundation

// MARK: - Chat Errors

enum ChatError: LocalizedError {
    case noApiKey
    case networkError
    case decodingError
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "No API key set. Add your Claude API key in Settings."
        case .networkError:
            return "Couldn't reach the AI service. Check your internet connection."
        case .decodingError:
            return "Received unexpected data from the AI service."
        case .apiError(let msg):
            return msg
        }
    }
}

// MARK: - API Response Models

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}

private struct ClaudeErrorResponse: Decodable {
    let error: ErrorDetail

    struct ErrorDetail: Decodable {
        let message: String
    }
}

// MARK: - Claude API Service

final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-20250514"
    private let apiVersion = "2023-06-01"

    private init() {}

    /// Send a conversation to Claude and return the assistant's reply.
    func sendMessage(
        systemPrompt: String,
        messages: [ChatMessage]
    ) async throws -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "claude_api_key"),
              !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ChatError.noApiKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = ClaudeRequest(
            model: model,
            max_tokens: 1024,
            system: systemPrompt,
            messages: messages.map {
                ClaudeMessage(
                    role: $0.role == .user ? "user" : "assistant",
                    content: $0.content
                )
            }
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ChatError.networkError
        }

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorBody = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ChatError.apiError(errorBody.error.message)
            }
            throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return decoded.content.compactMap(\.text).joined()
        } catch {
            throw ChatError.decodingError
        }
    }
}
