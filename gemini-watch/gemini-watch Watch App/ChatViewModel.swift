import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // 🔑 Loading API key from Secrets.plist
    private var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist.object(forKey: "GEMINI_API_KEY") as? String else {
            fatalError("Couldn't find key 'GEMINI_API_KEY' in 'Secrets.plist'.")
        }
        return value
    }
    
    // Updated to Gemini 2.5 Flash stable endpoint for 2026
    private let urlString = "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:streamGenerateContent"
    
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
            // Append an empty model message to fill as the stream arrives
            messages.append((role: "model", text: ""))
            let messageIndex = messages.count - 1
            
            do {
                for try await chunk in streamToGemini(prompt: prompt) {
                    isLoading = false // Hide loading spinner as soon as first chunk arrives
                    withAnimation(.easeIn) {
                        messages[messageIndex].text += chunk
                    }
                }
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
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
                    "contents": [["parts": [["text": prompt]]]]
                ]
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                do {
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    
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

struct GeminiResponse: Decodable { let candidates: [Candidate]? }
struct Candidate: Decodable { let content: Content }
struct Content: Decodable { let parts: [Part] }
struct Part: Decodable { let text: String? }
