import Foundation

enum MessageRole: String, Codable {
    case user
    case model
}

struct Message: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let role: MessageRole
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: MessageRole, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
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

    static let defaultSystemPrompt = "You are a helpful AI assistant. Be very concise — use short sentences, bullet points, and bold key terms. Avoid long paragraphs. Format for tiny screens."

    static let `default` = AppSettings(
        modelName: "gemini-2.5-flash",
        speechRate: 0.5,
        hapticsEnabled: true,
        suggestionsEnabled: true,
        systemPrompt: defaultSystemPrompt,
        temperature: 0.7
    )
}
