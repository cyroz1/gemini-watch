import Foundation

/// File-based persistence manager. Each conversation is stored as a separate
/// JSON file in the app's Documents directory, avoiding UserDefaults size limits
/// and main-thread blocking. Migrates legacy UserDefaults data on first run.
///
/// Metadata is cached in-memory and only invalidated on write/delete to avoid
/// repeated disk scans during streaming (#6).
class PersistenceManager {
    static let shared = PersistenceManager()

    private let settingsKey = "app_settings"
    private let defaults = UserDefaults.standard

    // Compact encoder for conversations (faster than prettyPrinted on the hot-path)
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
    private let decoder = JSONDecoder()

    private let conversationsDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("conversations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - In-Memory Metadata Cache (#6)

    private var metadataCache: [UUID: ConversationMetadata]? = nil

    private init() {
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - Conversations

    func loadConversationsMetadata() -> [ConversationMetadata] {
        if let cache = metadataCache {
            return Array(cache.values)
        }

        let files = (try? FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        var cache: [UUID: ConversationMetadata] = [:]
        for url in files {
            guard let data = try? Data(contentsOf: url),
                  let meta = try? decoder.decode(ConversationMetadata.self, from: data) else { continue }
            cache[meta.id] = meta
        }
        metadataCache = cache
        return Array(cache.values)
    }

    func loadConversation(id: UUID) -> Conversation? {
        let url = fileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Conversation.self, from: data)
    }

    func saveConversation(_ conversation: Conversation) {
        let url = fileURL(for: conversation.id)
        if let data = try? encoder.encode(conversation) {
            try? data.write(to: url, options: .atomic)
        }
        // Update in-memory cache
        let meta = ConversationMetadata(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            isPinned: conversation.isPinned
        )
        metadataCache?[conversation.id] = meta
    }

    func updateMetadata(_ meta: ConversationMetadata) {
        // Patch only the metadata fields by rewriting the metadata in the cache
        // and updating the full conversation file's pin/title fields.
        guard var convo = loadConversation(id: meta.id) else { return }
        convo.isPinned = meta.isPinned
        convo.title = meta.title
        saveConversation(convo)
    }

    func deleteConversation(id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
        metadataCache?[id] = nil
    }

    func deleteAllConversations() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: nil
        )) ?? []
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        metadataCache = [:]
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
