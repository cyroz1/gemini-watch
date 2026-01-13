import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // Loading API key from Secrets.plist
    private var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist.object(forKey: "GEMINI_API_KEY") as? String else {
            fatalError("Couldn't find key 'GEMINI_API_KEY' in 'Secrets.plist'.")
        }
        return value
    }
    
    // Using v1beta for Structured Output support (required for responseJsonSchema)
    private let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent"
    
    @Published var messages: [(role: String, text: String)] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingIndex: Int? = nil

    func resetChat() {
        messages = []
        errorMessage = nil
        isLoading = false
    }

    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        messages.append((role: "user", text: text))
        processRequest(prompt: text)
    }

    func editMessage(at index: Int, newText: String) {
        guard index < messages.count else { return }
        messages[index].text = newText
        
        // Remove subsequent model response to refresh the conversation
        if index + 1 < messages.count && messages[index + 1].role == "model" {
            messages.remove(at: index + 1)
        }
        processRequest(prompt: newText)
    }

    private func processRequest(prompt: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            var fullResponse = ""
            var messageIndex: Int? = nil
            var lastUpdate = Date()
            
            do {
                for try await chunk in streamToGemini(prompt: prompt) {
                    fullResponse += chunk
                    
                    let now = Date()
                    // Throttle updates to ~10fps or if it's the first non-empty chunk
                    if !fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if messageIndex == nil || now.timeIntervalSince(lastUpdate) > 0.1 {
                            isLoading = false
                            if messageIndex == nil {
                                // Add first model message
                                messages.append((role: "model", text: fullResponse))
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
                        messages.append((role: "model", text: fullResponse))
                    }
                }
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func streamToGemini(prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "\(urlString)?key=\(apiKey)&alt=sse") else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                
                let body: [String: Any] = [
                    "contents": [["parts": [["text": prompt]]]],
                    "system_instruction": [
                        "parts": [
                            ["text": "You are a helpful and conversational AI assistant. Be concise, friendly, and use markdown formatting (bolding, lists) when appropriate to make information easier to read on a small screen."]
                        ]
                    ]
                ]
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        continuation.finish(throwing: NSError(domain: "Gemini", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error: \(httpResponse.statusCode)"]))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                            if let data = jsonString.data(using: .utf8) {
                                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                                if let text = decoded.candidates?.first?.content.parts.first?.text {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// Data Structures for JSON Decoding
struct GeminiResponse: Decodable { let candidates: [Candidate]? }
struct Candidate: Decodable { let content: Content }
struct Content: Decodable { let parts: [Part] }
struct Part: Decodable { let text: String? }
