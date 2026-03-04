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

// MARK: - JSON Value (for decoding arbitrary tool inputs)

enum JSONValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    var intValue: Int? {
        if case .int(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        return nil
    }
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i):    try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b):   try container.encode(b)
        case .array(let a):  try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null:          try container.encodeNil()
        }
    }
}

// MARK: - Tool Definition Structs

struct ClaudeTool: Encodable {
    let name: String
    let description: String
    let input_schema: ToolInputSchema
}

struct ToolInputSchema: Encodable {
    let type: String
    let properties: [String: ToolProperty]
    let required: [String]
}

struct ToolProperty: Encodable {
    let type: String
    let description: String
    let `enum`: [String]?
    let items: ToolPropertyItems?

    init(type: String, description: String, enum enumValues: [String]? = nil, items: ToolPropertyItems? = nil) {
        self.type = type
        self.description = description
        self.enum = enumValues
        self.items = items
    }
}

struct ToolPropertyItems: Encodable {
    let type: String
}

// MARK: - API Message Payload (supports text + blocks)

struct ClaudeMessagePayload: Encodable {
    let role: String
    let content: PayloadContent

    enum PayloadContent: Encodable {
        case text(String)
        case blocks([ContentBlock])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s):    try container.encode(s)
            case .blocks(let b):  try container.encode(b)
            }
        }
    }

    struct ContentBlock: Encodable {
        let type: String
        // text block
        let text: String?
        // tool_use block
        let id: String?
        let name: String?
        let input: [String: JSONValue]?
        // tool_result block
        let tool_use_id: String?
        let content: String?

        // Convenience: text block
        static func text(_ text: String) -> ContentBlock {
            ContentBlock(type: "text", text: text, id: nil, name: nil, input: nil, tool_use_id: nil, content: nil)
        }

        // Convenience: tool_use block (echo back to API)
        static func toolUse(id: String, name: String, input: [String: JSONValue]) -> ContentBlock {
            ContentBlock(type: "tool_use", text: nil, id: id, name: name, input: input, tool_use_id: nil, content: nil)
        }

        // Convenience: tool_result block
        static func toolResult(toolUseId: String, content: String) -> ContentBlock {
            ContentBlock(type: "tool_result", text: nil, id: nil, name: nil, input: nil, tool_use_id: toolUseId, content: content)
        }

        // Custom encoding to skip nil fields
        enum CodingKeys: String, CodingKey {
            case type, text, id, name, input, tool_use_id, content
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            if let text      { try container.encode(text, forKey: .text) }
            if let id         { try container.encode(id, forKey: .id) }
            if let name       { try container.encode(name, forKey: .name) }
            if let input      { try container.encode(input, forKey: .input) }
            if let tool_use_id { try container.encode(tool_use_id, forKey: .tool_use_id) }
            if let content    { try container.encode(content, forKey: .content) }
        }
    }
}

// MARK: - API Result Types

struct ClaudeToolUse {
    let id: String
    let name: String
    let input: [String: JSONValue]
}

enum ClaudeResponseContent {
    case text(String)
    case toolUse(ClaudeToolUse)
}

struct ClaudeResult {
    let contentBlocks: [ClaudeResponseContent]
    let stopReason: String
}

// MARK: - Private Request/Response Models

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessagePayload]
    let tools: [ClaudeTool]?
}

private struct ClaudeResponse: Decodable {
    let content: [ResponseBlock]
    let stop_reason: String?

    struct ResponseBlock: Decodable {
        let type: String
        let text: String?
        // tool_use fields
        let id: String?
        let name: String?
        let input: [String: JSONValue]?
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

    // MARK: - Tool Definitions

    static var pulseDenTools: [ClaudeTool] {
        [
            ClaudeTool(
                name: "create_reminder",
                description: "Create a reminder for the user. Use ISO 8601 format for date_time (e.g. 2026-03-03T09:00:00). If the user says 'tomorrow', compute the actual date based on the current date provided in the system prompt.",
                input_schema: ToolInputSchema(
                    type: "object",
                    properties: [
                        "title": ToolProperty(type: "string", description: "The reminder title"),
                        "emoji": ToolProperty(type: "string", description: "An emoji for the reminder (default: 🔔)"),
                        "note": ToolProperty(type: "string", description: "Optional additional notes"),
                        "date_time": ToolProperty(type: "string", description: "When to remind, in ISO 8601 format (e.g. 2026-03-03T09:00:00)"),
                        "repeat_option": ToolProperty(type: "string", description: "Repeat frequency", enum: ["once", "daily", "weekly", "monthly"])
                    ],
                    required: ["title", "date_time"]
                )
            ),
            ClaudeTool(
                name: "create_note",
                description: "Create a note (stuff item) for the user. Use this when they want to save, bookmark, or remember something.",
                input_schema: ToolInputSchema(
                    type: "object",
                    properties: [
                        "title": ToolProperty(type: "string", description: "The note title"),
                        "emoji": ToolProperty(type: "string", description: "An emoji for the note (default: 📌)"),
                        "note": ToolProperty(type: "string", description: "The note content/details"),
                        "category": ToolProperty(type: "string", description: "Category of the note", enum: ["recipe", "article", "idea", "place", "product", "other"]),
                        "rating": ToolProperty(type: "integer", description: "Rating from 1-5 (default: 3)")
                    ],
                    required: ["title"]
                )
            ),
            ClaudeTool(
                name: "create_habit",
                description: "Create a new habit for the user to track daily or on specific weekdays.",
                input_schema: ToolInputSchema(
                    type: "object",
                    properties: [
                        "name": ToolProperty(type: "string", description: "The habit name"),
                        "emoji": ToolProperty(type: "string", description: "An emoji for the habit (default: ✅)"),
                        "frequency": ToolProperty(type: "string", description: "How often: 'daily' or 'weekdays'", enum: ["daily", "weekdays"]),
                        "weekdays": ToolProperty(type: "array", description: "Which weekdays (1=Sun, 2=Mon, ... 7=Sat). Only used when frequency is 'weekdays'.", items: ToolPropertyItems(type: "integer"))
                    ],
                    required: ["name"]
                )
            )
        ]
    }

    // MARK: - Send with Tools

    /// Send a conversation to Claude with tool support and return structured result.
    func sendMessageWithTools(
        systemPrompt: String,
        messages: [ClaudeMessagePayload],
        tools: [ClaudeTool]? = nil
    ) async throws -> ClaudeResult {
        guard let apiKey = UserDefaults.standard.string(forKey: "claude_api_key"),
              !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ChatError.noApiKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = ClaudeRequest(
            model: model,
            max_tokens: 1024,
            system: systemPrompt,
            messages: messages,
            tools: tools
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ChatError.networkError
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorBody = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ChatError.apiError(errorBody.error.message)
            }
            throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)

            let blocks: [ClaudeResponseContent] = decoded.content.compactMap { block in
                switch block.type {
                case "text":
                    guard let text = block.text else { return nil }
                    return .text(text)
                case "tool_use":
                    guard let id = block.id, let name = block.name else { return nil }
                    return .toolUse(ClaudeToolUse(id: id, name: name, input: block.input ?? [:]))
                default:
                    return nil
                }
            }

            return ClaudeResult(
                contentBlocks: blocks,
                stopReason: decoded.stop_reason ?? "end_turn"
            )
        } catch {
            throw ChatError.decodingError
        }
    }

    // MARK: - Legacy (simple text)

    /// Send a conversation to Claude and return the assistant's text reply.
    func sendMessage(
        systemPrompt: String,
        messages: [ChatMessage]
    ) async throws -> String {
        let payloads = messages.map {
            ClaudeMessagePayload(
                role: $0.role == .user ? "user" : "assistant",
                content: .text($0.content)
            )
        }
        let result = try await sendMessageWithTools(
            systemPrompt: systemPrompt,
            messages: payloads,
            tools: nil
        )
        return result.contentBlocks.compactMap {
            if case .text(let t) = $0 { return t }
            return nil
        }.joined()
    }
}
