import Foundation

enum MessageRole: String, Codable {
    case user
    case model
}

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    var text: String
    
    init(id: UUID = UUID(), role: MessageRole, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
