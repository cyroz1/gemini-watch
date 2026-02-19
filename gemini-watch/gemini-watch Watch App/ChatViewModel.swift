import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingMessageId: UUID? = nil
    @Published var suggestions: [String] = []
    /// ID of the message currently being streamed — used to show a typing cursor.
    @Published var streamingMessageId: UUID? = nil

    private let geminiService = GeminiService()
    private let persistence = PersistenceManager.shared
    private var streamTask: Task<Void, Never>?

    // Debounce onUpdate so the conversation list doesn't reload on every streaming chunk
    private var updateWorkItem: DispatchWorkItem?

    var conversationId: UUID?

    // MARK: - Conversation Management

    func loadConversation(_ conversation: Conversation) {
        conversationId = conversation.id
        messages = conversation.messages
        errorMessage = nil
        isLoading = false
        suggestions = []
        streamingMessageId = nil
    }

    func resetChat() {
        streamTask?.cancel()
        streamTask = nil
        messages = []
        errorMessage = nil
        isLoading = false
        editingMessageId = nil
        suggestions = []
        streamingMessageId = nil

        let newConvo = Conversation()
        conversationId = newConvo.id
        persistence.saveConversation(newConvo)
    }

    // MARK: - Messaging

    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        let userMessage = Message(role: .user, text: text)
        messages.append(userMessage)
        suggestions = []
        persistCurrentState()
        processRequest()
    }

    func editMessage(id: UUID, newText: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = newText

        if index + 1 < messages.count && messages[index + 1].role == .model {
            messages.remove(at: index + 1)
        }

        suggestions = []
        persistCurrentState()
        processRequest()
        editingMessageId = nil
    }

    // MARK: - Streaming

    private func processRequest() {
        streamTask?.cancel()
        isLoading = true
        errorMessage = nil

        let settings = persistence.loadSettings()

        streamTask = Task {
            var fullResponse = ""
            var messageIndex: Int? = nil
            var lastUpdate = Date()

            do {
                let stream = await geminiService.streamGenerateContent(
                    messages: messages,
                    model: settings.modelName,
                    systemPrompt: settings.systemPrompt
                )
                for try await chunk in stream {
                    if Task.isCancelled { return }
                    fullResponse += chunk

                    let now = Date()
                    if !fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if messageIndex == nil || now.timeIntervalSince(lastUpdate) > 0.1 {
                            isLoading = false
                            if messageIndex == nil {
                                let modelMessage = Message(role: .model, text: fullResponse)
                                messages.append(modelMessage)
                                messageIndex = messages.count - 1
                                streamingMessageId = modelMessage.id
                            } else {
                                messages[messageIndex!].text = fullResponse
                            }
                            lastUpdate = now
                        }
                    }
                }

                // Final update
                if !fullResponse.isEmpty {
                    if let idx = messageIndex {
                        messages[idx].text = fullResponse
                    } else {
                        let msg = Message(role: .model, text: fullResponse)
                        messages.append(msg)
                    }
                }

                streamingMessageId = nil
                isLoading = false
                persistCurrentState()

                if settings.suggestionsEnabled {
                    generateSuggestions()
                }
            } catch {
                streamingMessageId = nil
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Suggestions

    private func generateSuggestions() {
        guard let lastModel = messages.last(where: { $0.role == .model }) else { return }
        let text = lastModel.text.lowercased()

        if text.contains("```") || text.contains("func ") || text.contains("var ") || text.contains("class ") {
            suggestions = ["Explain this code", "Show an example", "How do I use this?"]
        } else if text.contains("• ") || text.contains("1.") || text.contains("step") {
            suggestions = ["Tell me more", "Summarize this", "Why?"]
        } else if text.hasSuffix("?") || text.contains("you can") || text.contains("you could") {
            suggestions = ["Yes, do it", "Explain further", "Give an example"]
        } else {
            suggestions = ["Explain more", "Simplify", "Give an example"]
        }
    }

    // MARK: - Persistence

    func scheduleUpdate(_ onUpdate: (() -> Void)?) {
        updateWorkItem?.cancel()
        let item = DispatchWorkItem { onUpdate?() }
        updateWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func persistCurrentState() {
        guard let id = conversationId else { return }
        var convo = Conversation(id: id, messages: messages)
        convo.updatedAt = Date()
        convo.autoTitle()

        if let existing = persistence.loadConversations().first(where: { $0.id == id }) {
            convo.createdAt = existing.createdAt
        }

        persistence.saveConversation(convo)
    }
}
