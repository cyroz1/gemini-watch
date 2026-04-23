import Foundation
import Combine

/// Shared, reactive settings store. Injected once at the app root as an
/// `.environmentObject` so all views read and write settings without
/// accessing the disk themselves.
@MainActor
class AppSettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            PersistenceManager.shared.saveSettings(settings)
        }
    }

    init() {
        settings = PersistenceManager.shared.loadSettings()
    }
}
