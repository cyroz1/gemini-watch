import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let conversationsKey = "saved_conversations"
    private let settingsKey = "app_settings"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {}
    
    // MARK: - Conversations
    
    func loadConversations() -> [Conversation] {
        guard let data = defaults.data(forKey: conversationsKey) else { return [] }
        return (try? decoder.decode([Conversation].self, from: data)) ?? []
    }
    
    func saveConversation(_ conversation: Conversation) {
        var all = loadConversations()
        if let idx = all.firstIndex(where: { $0.id == conversation.id }) {
            all[idx] = conversation
        } else {
            all.insert(conversation, at: 0)
        }
        saveAll(all)
    }
    
    func deleteConversation(id: UUID) {
        var all = loadConversations()
        all.removeAll { $0.id == id }
        saveAll(all)
    }
    
    func deleteAllConversations() {
        saveAll([])
    }
    
    private func saveAll(_ conversations: [Conversation]) {
        if let data = try? encoder.encode(conversations) {
            defaults.set(data, forKey: conversationsKey)
        }
    }
    
    // MARK: - Settings
    
    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else { return .default }
        return (try? decoder.decode(AppSettings.self, from: data)) ?? .default
    }
    
    func saveSettings(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
}
