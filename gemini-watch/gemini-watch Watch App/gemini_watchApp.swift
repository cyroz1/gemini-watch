import SwiftUI
import UserNotifications

@main
struct gemini_watchApp: App {
    @StateObject private var settingsStore = AppSettingsStore()
    @StateObject private var speaker = Speaker.shared

    var body: some Scene {
        WindowGroup {
            ConversationListView()
                .environmentObject(settingsStore)
                .environmentObject(speaker)
        }
    }

    init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
