import Foundation

/// File-based persistence manager. Each conversation is stored as a separate
/// JSON file in the app's Documents directory, avoiding UserDefaults size limits
/// and main-thread blocking. Migrates legacy UserDefaults data on first run.
///
/// Metadata is cached in-memory and written to a sidecar `_index.json` file, so
/// repeated launches don't re-decode every conversation payload to rebuild the
/// list (#6).
final class PersistenceManager: @unchecked Sendable {
    static let shared = PersistenceManager()

    private let settingsKey = "app_settings"
    private let defaults = UserDefaults.standard

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let ioQueue = DispatchQueue(label: "gemini-watch.persistence", qos: .utility)

    private let conversationsDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("conversations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var indexURL: URL { conversationsDir.appendingPathComponent("_index.json") }

    // MARK: - In-Memory Metadata Cache (#6)

    private var metadataCache: [UUID: ConversationMetadata]?
    private let cacheLock = NSLock()

    private init() {
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - Conversations

    func loadConversationsMetadata() -> [ConversationMetadata] {
        cacheLock.lock()
        if let cache = metadataCache {
            let values = Array(cache.values)
            cacheLock.unlock()
            return values
        }
        cacheLock.unlock()

        // Fast path: load sidecar index if present.
        if let data = try? Data(contentsOf: indexURL),
           let list = try? decoder.decode([ConversationMetadata].self, from: data) {
            let dict = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            cacheLock.lock()
            metadataCache = dict
            cacheLock.unlock()
            return list
        }

        // Slow path: scan conversation files and rebuild the index.
        let files = (try? FileManager.default.contentsOfDirectory(
            at: conversationsDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []

        var dict: [UUID: ConversationMetadata] = [:]
        for url in files where url.pathExtension == "json" && url.lastPathComponent != "_index.json" {
            guard let data = try? Data(contentsOf: url),
                  let meta = try? decoder.decode(ConversationMetadata.self, from: data) else { continue }
            dict[meta.id] = meta
        }

        cacheLock.lock()
        metadataCache = dict
        cacheLock.unlock()

        writeIndex(dict)
        return Array(dict.values)
    }

    func loadConversation(id: UUID) -> Conversation? {
        let url = fileURL(for: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Conversation.self, from: data)
    }

    /// Async write. Safe to call from the main actor during streaming — the
    /// encode and atomic write happen on a background queue so the UI stays
    /// responsive. The in-memory metadata cache is updated synchronously so
    /// subsequent reads reflect the change immediately.
    func saveConversation(_ conversation: Conversation) {
        let meta = ConversationMetadata(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            isPinned: conversation.isPinned
        )

        cacheLock.lock()
        if metadataCache == nil { metadataCache = [:] }
        metadataCache?[conversation.id] = meta
        let snapshot = metadataCache
        cacheLock.unlock()

        let url = fileURL(for: conversation.id)
        let encoder = self.encoder
        ioQueue.async { [weak self] in
            guard let self else { return }
            if let data = try? encoder.encode(conversation) {
                try? data.write(to: url, options: .atomic)
            }
            if let snapshot { self.writeIndex(snapshot) }
        }
    }

    func updateMetadata(_ meta: ConversationMetadata) {
        guard var convo = loadConversation(id: meta.id) else { return }
        convo.isPinned = meta.isPinned
        convo.title = meta.title
        saveConversation(convo)
    }

    func deleteConversation(id: UUID) {
        cacheLock.lock()
        metadataCache?[id] = nil
        let snapshot = metadataCache
        cacheLock.unlock()

        let url = fileURL(for: id)
        ioQueue.async { [weak self] in
            try? FileManager.default.removeItem(at: url)
            if let snapshot { self?.writeIndex(snapshot) }
        }
    }

    func deleteAllConversations() {
        cacheLock.lock()
        metadataCache = [:]
        cacheLock.unlock()

        let dir = conversationsDir
        ioQueue.async { [weak self] in
            let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            files.forEach { try? FileManager.default.removeItem(at: $0) }
            self?.writeIndex([:])
        }
    }

    private func fileURL(for id: UUID) -> URL {
        conversationsDir.appendingPathComponent("\(id.uuidString).json")
    }

    private func writeIndex(_ dict: [UUID: ConversationMetadata]) {
        // Always called from ioQueue (or from a context where order doesn't matter).
        let list = Array(dict.values)
        if let data = try? encoder.encode(list) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    // MARK: - Settings (UserDefaults is fine for small settings structs)

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else { return .default }
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
