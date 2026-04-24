import Foundation

enum MessageRole: String, Codable {
    case user
    case model
}

struct GroundingSource: Codable, Equatable, Hashable, Identifiable {
    let uri: String
    let title: String

    var id: String { uri }
}

struct Message: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let role: MessageRole
    var text: String
    let createdAt: Date
    /// Web-search grounding sources attached to this response, if any.
    /// Optional so older persisted messages (without the field) still decode.
    var sources: [GroundingSource]?

    init(id: UUID = UUID(),
         role: MessageRole,
         text: String,
         createdAt: Date = Date(),
         sources: [GroundingSource]? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.sources = sources
    }
}

struct Conversation: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]
    var isPinned: Bool

    init(id: UUID = UUID(), title: String = "New Chat", messages: [Message] = [], isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = messages
        self.isPinned = isPinned
    }

    /// Auto-generate title from first user message
    mutating func autoTitle() {
        if let first = messages.first(where: { $0.role == .user }) {
            let raw = first.text.prefix(40)
            title = raw.count < first.text.count ? "\(raw)…" : String(raw)
        }
    }
}

struct ConversationMetadata: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(id: UUID, title: String, createdAt: Date, updatedAt: Date, isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
}

struct AppSettings: Codable, Equatable {
    var modelName: String
    var speechRate: Float
    var hapticsEnabled: Bool
    var suggestionsEnabled: Bool
    var systemPrompt: String
    var temperature: Double
    /// Enable Gemini's `google_search` tool for grounded answers with citations.
    var webSearchEnabled: Bool

    // Codable back-compat — older persisted settings don't have webSearchEnabled.
    private enum CodingKeys: String, CodingKey {
        case modelName, speechRate, hapticsEnabled, suggestionsEnabled
        case systemPrompt, temperature, webSearchEnabled
    }

    init(modelName: String,
         speechRate: Float,
         hapticsEnabled: Bool,
         suggestionsEnabled: Bool,
         systemPrompt: String,
         temperature: Double,
         webSearchEnabled: Bool = false) {
        self.modelName = modelName
        self.speechRate = speechRate
        self.hapticsEnabled = hapticsEnabled
        self.suggestionsEnabled = suggestionsEnabled
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.webSearchEnabled = webSearchEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modelName = try c.decode(String.self, forKey: .modelName)
        speechRate = try c.decode(Float.self, forKey: .speechRate)
        hapticsEnabled = try c.decode(Bool.self, forKey: .hapticsEnabled)
        suggestionsEnabled = try c.decode(Bool.self, forKey: .suggestionsEnabled)
        systemPrompt = try c.decode(String.self, forKey: .systemPrompt)
        temperature = try c.decode(Double.self, forKey: .temperature)
        webSearchEnabled = try c.decodeIfPresent(Bool.self, forKey: .webSearchEnabled) ?? false
    }

    static let defaultSystemPrompt = "You are a helpful AI assistant. Be very concise — use short sentences, bullet points, and bold key terms. Avoid long paragraphs. Format for tiny screens."

    static let `default` = AppSettings(
        modelName: "gemini-2.5-flash",
        speechRate: 0.5,
        hapticsEnabled: true,
        suggestionsEnabled: true,
        systemPrompt: defaultSystemPrompt,
        temperature: 0.7,
        webSearchEnabled: false
    )
}
