import SwiftUI

struct SettingsView: View {
    @State private var settings: AppSettings = PersistenceManager.shared.loadSettings()
    @State private var showClearConfirm = false
    
    var onClearAll: () -> Void
    
    private let persistence = PersistenceManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Model Selection
                Section {
                    Picker("Model", selection: $settings.modelName) {
                        ForEach(AppSettings.availableModels, id: \.self) { model in
                            Text(model.replacingOccurrences(of: "gemini-", with: ""))
                                .font(.caption2)
                                .tag(model)
                        }
                    }
                    .font(.caption2)
                } header: {
                    Text("AI Model")
                        .font(.system(size: 9))
                }
                
                // Speech
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed: \(speedLabel)")
                            .font(.caption2)
                        Slider(value: $settings.speechRate, in: 0.3...0.7, step: 0.1)
                    }
                } header: {
                    Text("Speech")
                        .font(.system(size: 9))
                }
                
                // Toggles
                Section {
                    Toggle(isOn: $settings.hapticsEnabled) {
                        Text("Haptics")
                            .font(.caption2)
                    }
                    Toggle(isOn: $settings.suggestionsEnabled) {
                        Text("Quick Replies")
                            .font(.caption2)
                    }
                } header: {
                    Text("Features")
                        .font(.system(size: 9))
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Chats")
                        }
                        .font(.caption2)
                        .foregroundStyle(.red)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Settings")
            .onChange(of: settings) {
                persistence.saveSettings(settings)
            }
            .confirmationDialog("Delete all chats?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    persistence.deleteAllConversations()
                    onClearAll()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var speedLabel: String {
        switch settings.speechRate {
        case ..<0.4: return "Slow"
        case 0.4..<0.6: return "Normal"
        default: return "Fast"
        }
    }
}
