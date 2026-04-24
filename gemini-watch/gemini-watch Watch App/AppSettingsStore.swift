import Foundation
import Combine

/// Shared, reactive settings store. Injected once at the app root as an
/// `.environmentObject` so all views read and write settings without
/// accessing the disk themselves.
@MainActor
class AppSettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { scheduleSave() }
    }

    // Debounce disk writes — sliders emit many values per drag and we don't
    // need to persist every intermediate tick.
    private var saveTask: Task<Void, Never>?

    init() {
        settings = PersistenceManager.shared.loadSettings()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = settings
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms
            guard !Task.isCancelled else { return }
            PersistenceManager.shared.saveSettings(snapshot)
            self?.saveTask = nil
        }
    }
}
