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

// MARK: - Type-Erased Encodable Wrapper

/// Wraps any `Encodable` value so heterogeneous types (client tools, server tools)
/// can live in the same `[AnyEncodable]` array.
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Web Search Tool (Server-Side)

/// Anthropic's server-side web search tool.
/// Encoded as: {"type": "web_search_20250305", "name": "web_search", "max_uses": N}
struct WebSearchTool: Encodable {
    let type = "web_search_20250305"
    let name = "web_search"
    let max_uses: Int

    init(maxUses: Int = 5) {
        self.max_uses = maxUses
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
        /// Raw JSON content for round-tripping server tool responses (web search, etc.)
        case rawJSON([JSONValue])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s):      try container.encode(s)
            case .blocks(let b):    try container.encode(b)
            case .rawJSON(let j):   try container.encode(j)
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
    /// Raw response content blocks as JSONValue for multi-turn round-tripping.
    /// Preserves server_tool_use, web_search_tool_result (with encrypted_content),
    /// and text blocks with citations — all needed for follow-up context.
    let rawContentJSON: [JSONValue]
}

// MARK: - Private Request/Response Models

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessagePayload]
    let tools: [AnyEncodable]?
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
//
// Uses Swift `actor` to guarantee ALL work (JSON encoding, networking,
// JSON decoding) runs on the actor's own background executor — never
// on the main thread. This prevents the 100% CPU / frozen UI issue
// on physical iPhones where previous approaches (Task.detached,
// withThrowingTaskGroup racing, ephemeral sessions) all failed.

actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"
    private let apiVersion = "2023-06-01"

    /// Single URLSession — reused across requests.
    /// Actor isolation ensures no concurrent access issues.
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.httpShouldUsePipelining = false
        session = URLSession(configuration: config)
    }

    // MARK: - Tool Definitions

    static var grogyBotTools: [AnyEncodable] {
        let clientTools: [ClaudeTool] = [
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
                description: "Create a note for the user. Use this when they want to save, write down, or remember something.",
                input_schema: ToolInputSchema(
                    type: "object",
                    properties: [
                        "title": ToolProperty(type: "string", description: "The note title"),
                        "emoji": ToolProperty(type: "string", description: "An emoji for the note (default: 📝)"),
                        "note": ToolProperty(type: "string", description: "The note body/content")
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

        // Wrap client tools + add server-side web search tool
        var allTools = clientTools.map { AnyEncodable($0) }
        allTools.append(AnyEncodable(WebSearchTool(maxUses: 5)))
        return allTools
    }

    // MARK: - Send with Tools

    /// Send a conversation to Claude with tool support and return structured result.
    /// Because ClaudeAPIService is an `actor`, this entire method — JSON encoding,
    /// networking, JSON decoding — runs on the actor's background executor,
    /// never on the main thread.
    func sendMessageWithTools(
        systemPrompt: String,
        messages: [ClaudeMessagePayload],
        tools: [AnyEncodable]? = nil
    ) async throws -> ClaudeResult {
        guard let apiKey = UserDefaults.standard.string(forKey: "claude_api_key"),
              !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ChatError.noApiKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = ClaudeRequest(
            model: model,
            max_tokens: 4096,
            system: systemPrompt,
            messages: messages,
            tools: tools
        )

        print("[ClaudeAPI] Encoding request...")
        request.httpBody = try JSONEncoder().encode(body)
        print("[ClaudeAPI] Encoded \(request.httpBody?.count ?? 0) bytes, starting network request...")

        // Simple async/await — actor isolation keeps this off the main thread.
        // URLSession.data(for:) respects Swift task cancellation automatically.
        let (data, response) = try await session.data(for: request)
        print("[ClaudeAPI] Received \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.networkError
        }

        if httpResponse.statusCode != 200 {
            if let errorBody = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ChatError.apiError(errorBody.error.message)
            }
            throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
        }

        print("[ClaudeAPI] Decoding response...")
        do {
            // 1. Decode raw JSON to preserve ALL block types for multi-turn round-tripping
            //    (server_tool_use, web_search_tool_result with encrypted_content, citations, etc.)
            let rawJSON = try JSONDecoder().decode(JSONValue.self, from: data)
            let rawContentJSON: [JSONValue]
            if case .object(let root) = rawJSON,
               case .array(let contentArray) = root["content"] ?? .null {
                rawContentJSON = contentArray
            } else {
                rawContentJSON = []
            }

            // 2. Decode with typed struct for convenient text/tool_use extraction
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
                    // server_tool_use, web_search_tool_result — preserved in rawContentJSON
                    return nil
                }
            }

            print("[ClaudeAPI] Done — stopReason: \(decoded.stop_reason ?? "nil")")
            return ClaudeResult(
                contentBlocks: blocks,
                stopReason: decoded.stop_reason ?? "end_turn",
                rawContentJSON: rawContentJSON
            )
        } catch {
            print("[ClaudeAPI] Decode error: \(error)")
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
