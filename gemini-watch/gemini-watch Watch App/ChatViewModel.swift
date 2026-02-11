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
    
    private let geminiService = GeminiService()
    private let persistence = PersistenceManager.shared
    private var streamTask: Task<Void, Never>?
    
    var conversationId: UUID?
    
    // MARK: - Conversation Management
    
    func loadConversation(_ conversation: Conversation) {
        conversationId = conversation.id
        messages = conversation.messages
        errorMessage = nil
        isLoading = false
        suggestions = []
    }
    
    func resetChat() {
        streamTask?.cancel()
        streamTask = nil
        messages = []
        errorMessage = nil
        isLoading = false
        editingMessageId = nil
        suggestions = []
        
        // Create a fresh conversation
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
        
        // Remove subsequent model response
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
                    model: settings.modelName
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
                        messages.append(Message(role: .model, text: fullResponse))
                    }
                }
                isLoading = false
                persistCurrentState()
                
                // Generate quick-reply suggestions
                if settings.suggestionsEnabled {
                    generateSuggestions()
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Suggestions
    
    private func generateSuggestions() {
        let lastRole = messages.last?.role
        guard lastRole == .model else { return }
        
        // Context-aware static suggestions
        suggestions = ["Explain more", "Summarize", "Give an example"]
    }
    
    // MARK: - Persistence
    
    private func persistCurrentState() {
        guard let id = conversationId else { return }
        var convo = Conversation(id: id, messages: messages)
        convo.updatedAt = Date()
        convo.autoTitle()
        
        // Preserve original creation date
        if let existing = persistence.loadConversations().first(where: { $0.id == id }) {
            convo.createdAt = existing.createdAt
        }
        
        persistence.saveConversation(convo)
    }
}
