import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @State private var showClearConfirm = false
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = true
    @State private var modelError: String?

    var onClearAll: () -> Void

    /// Passed in from the root so we reuse the same service instance (#17)
    private let geminiService: GeminiService
    private let persistence = PersistenceManager.shared

    init(geminiService: GeminiService, onClearAll: @escaping () -> Void) {
        self.geminiService = geminiService
        self.onClearAll = onClearAll
    }

    var body: some View {
        NavigationStack {
            List {
                // Model Selection
                Section {
                    if isLoadingModels {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading models…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else if let error = modelError {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else {
                        Picker("Model", selection: $settingsStore.settings.modelName) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(model.replacingOccurrences(of: "gemini-", with: ""))
                                    .font(.caption2)
                                    .tag(model)
                            }
                        }
                        .font(.caption2)
                    }
                } header: {
                    Text("AI Model")
                        .font(.system(size: 9))
                }

                // Speech
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speed: \(speedLabel)")
                            .font(.caption2)
                        Slider(value: $settingsStore.settings.speechRate, in: 0.3...0.7, step: 0.1)
                    }
                } header: {
                    Text("Speech")
                        .font(.system(size: 9))
                }

                // Creativity (#12)
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Creativity: \(creativityLabel)")
                            .font(.caption2)
                        Slider(value: $settingsStore.settings.temperature, in: 0.0...1.0, step: 0.1)
                    }
                    Button("Reset to Default") {
                        settingsStore.settings.temperature = 0.7
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Creativity")
                        .font(.system(size: 9))
                }

                // Toggles
                Section {
                    Toggle(isOn: $settingsStore.settings.hapticsEnabled) {
                        Text("Haptics")
                            .font(.caption2)
                    }
                    Toggle(isOn: $settingsStore.settings.suggestionsEnabled) {
                        Text("Quick Replies")
                            .font(.caption2)
                    }
                } header: {
                    Text("Features")
                        .font(.system(size: 9))
                }

                // System Prompt
                Section {
                    TextField("System prompt…", text: $settingsStore.settings.systemPrompt, axis: .vertical)
                        .font(.system(size: 9))
                        .lineLimit(4, reservesSpace: true)
                    Button("Reset to Default") {
                        settingsStore.settings.systemPrompt = AppSettings.defaultSystemPrompt
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                } header: {
                    Text("System Prompt")
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
            .confirmationDialog("Delete all chats?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    persistence.deleteAllConversations()
                    onClearAll()
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await fetchModels()
            }
        }
    }

    private var speedLabel: String {
        switch settingsStore.settings.speechRate {
        case ..<0.4: return "Slow"
        case 0.4..<0.6: return "Normal"
        default: return "Fast"
        }
    }

    private var creativityLabel: String {
        switch settingsStore.settings.temperature {
        case ..<0.3: return "Precise"
        case 0.3..<0.6: return "Balanced"
        case 0.6..<0.85: return "Creative"
        default: return "Wild"
        }
    }

    private func fetchModels() async {
        do {
            let models = try await geminiService.listModels()
            availableModels = models

            // If current selection isn't in the list, keep it anyway
            if !models.contains(settingsStore.settings.modelName) && !models.isEmpty {
                availableModels.insert(settingsStore.settings.modelName, at: 0)
            }

            isLoadingModels = false
        } catch {
            modelError = "Couldn't load models"
            availableModels = [settingsStore.settings.modelName]
            isLoadingModels = false
        }
    }
}
