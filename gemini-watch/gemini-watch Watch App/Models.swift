import Foundation

enum MessageRole: String, Codable {
    case user
    case model
}

struct Message: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let role: MessageRole
    var text: String
    
    init(id: UUID = UUID(), role: MessageRole, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

struct Conversation: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]
    
    init(id: UUID = UUID(), title: String = "New Chat", messages: [Message] = []) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = messages
    }
    
    /// Auto-generate title from first user message
    mutating func autoTitle() {
        if let first = messages.first(where: { $0.role == .user }) {
            let raw = first.text.prefix(40)
            title = raw.count < first.text.count ? "\(raw)…" : String(raw)
        }
    }
}

struct AppSettings: Codable, Equatable {
    var modelName: String
    var speechRate: Float
    var hapticsEnabled: Bool
    var suggestionsEnabled: Bool
    
    static let `default` = AppSettings(
        modelName: "gemini-2.5-flash",
        speechRate: 0.5,
        hapticsEnabled: true,
        suggestionsEnabled: true
    )
}
