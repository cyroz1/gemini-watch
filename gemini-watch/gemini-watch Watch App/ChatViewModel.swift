import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingMessageId: UUID? = nil
    
    private let geminiService = GeminiService()

    func resetChat() {
        messages = []
        errorMessage = nil
        isLoading = false
    }

    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        let userMessage = Message(role: .user, text: text)
        messages.append(userMessage)
        processRequest()
    }

    func editMessage(id: UUID, newText: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = newText
        
        // Remove subsequent model response to refresh the conversation
        // The previous logic was index + 1, assuming simple alternating. 
        // We should probably remove everything *after* this message to be safe and replay history,
        // but sticking to the simple "remove next if model" logic for now to match behavior.
        if index + 1 < messages.count && messages[index + 1].role == .model {
            messages.remove(at: index + 1)
        }
        
        // Also remove any subsequent messages if we want strictly "restart from here" logic?
        // For a simple edit, let's just re-generate the answer.
        processRequest()
        editingMessageId = nil
    }

    private func processRequest() {
        isLoading = true
        errorMessage = nil
        
        Task {
            var fullResponse = ""
            var messageIndex: Int? = nil
            var lastUpdate = Date()
            
            do {
                // Pass the current history to the service
                let stream = await geminiService.streamGenerateContent(messages: messages)
                for try await chunk in stream {
                    fullResponse += chunk
                    
                    let now = Date()
                    // Throttle updates to ~10fps or if it's the first non-empty chunk
                    if !fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if messageIndex == nil || now.timeIntervalSince(lastUpdate) > 0.1 {
                            isLoading = false // Start showing content
                            if messageIndex == nil {
                                // Add first model message
                                let modelMessage = Message(role: .model, text: fullResponse)
                                messages.append(modelMessage)
                                messageIndex = messages.count - 1
                            } else {
                                // Update existing model message
                                messages[messageIndex!].text = fullResponse
                            }
                            lastUpdate = now
                        }
                    }
                }
                
                // Final update after stream finishes
                if !fullResponse.isEmpty {
                    if let idx = messageIndex {
                        messages[idx].text = fullResponse
                    } else {
                        messages.append(Message(role: .model, text: fullResponse))
                    }
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// Data Structures for JSON Decoding

