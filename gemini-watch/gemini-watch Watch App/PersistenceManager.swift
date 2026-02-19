import Foundation

/// File-based persistence manager. Each conversation is stored as a separate
/// JSON file in the app's Documents directory, avoiding UserDefaults size limits
/// and main-thread blocking. Migrates legacy UserDefaults data on first run.
class PersistenceManager {
    static let shared = PersistenceManager()

    private let settingsKey = "app_settings"
    private let defaults = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()
    private let decoder = JSONDecoder()

    private let conversationsDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("conversations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - Conversations

    func loadConversations() -> [Conversation] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return files.compactMap { url -> Conversation? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(Conversation.self, from: data)
        }
    }

    func saveConversation(_ conversation: Conversation) {
        let url = fileURL(for: conversation.id)
        if let data = try? encoder.encode(conversation) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func deleteConversation(id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func deleteAllConversations() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: nil
        )) ?? []
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private func fileURL(for id: UUID) -> URL {
        conversationsDir.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - Settings (UserDefaults is fine for small settings structs)

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else { return .default }
        // Decode and handle missing keys from older versions gracefully
        return (try? decoder.decode(AppSettings.self, from: data)) ?? .default
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Migration

    private func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "conversations_migrated_v2"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let legacyKey = "saved_conversations"
        if let data = defaults.data(forKey: legacyKey),
           let legacy = try? decoder.decode([Conversation].self, from: data) {
            legacy.forEach { saveConversation($0) }
            defaults.removeObject(forKey: legacyKey)
        }

        defaults.set(true, forKey: migrationKey)
    }
}
