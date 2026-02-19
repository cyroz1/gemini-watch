import SwiftUI

struct SettingsView: View {
    @State private var settings: AppSettings = PersistenceManager.shared.loadSettings()
    @State private var showClearConfirm = false
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = true
    @State private var modelError: String?
    
    var onClearAll: () -> Void
    
    private let persistence = PersistenceManager.shared
    private let geminiService = GeminiService()
    
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
                        Picker("Model", selection: $settings.modelName) {
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

                // System Prompt
                Section {
                    TextField("System prompt…", text: $settings.systemPrompt, axis: .vertical)
                        .font(.system(size: 9))
                        .lineLimit(4, reservesSpace: true)
                    Button("Reset to Default") {
                        settings.systemPrompt = AppSettings.defaultSystemPrompt
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
            .task {
                await fetchModels()
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
    
    private func fetchModels() async {
        do {
            let models = try await geminiService.listModels()
            availableModels = models
            
            // If current selection isn't in the list, keep it anyway
            if !models.contains(settings.modelName) && !models.isEmpty {
                // Don't force-change — the user's saved model might still work
                availableModels.insert(settings.modelName, at: 0)
            }
            
            isLoadingModels = false
        } catch {
            modelError = "Couldn't load models"
            // Fall back to current saved model so picker still works
            availableModels = [settings.modelName]
            isLoadingModels = false
        }
    }
}
