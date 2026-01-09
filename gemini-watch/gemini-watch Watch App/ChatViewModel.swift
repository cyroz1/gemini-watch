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
    private let urlString = "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent"
    
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
            do {
                let responseText = try await sendToGemini(prompt: prompt)
                messages.append((role: "model", text: responseText))
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func sendToGemini(prompt: String) async throws -> String {
        guard let url = URL(string: "\(urlString)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decodedResponse.candidates?.first?.content.parts.first?.text ?? "No response."
    }
}

struct GeminiResponse: Decodable { let candidates: [Candidate]? }
struct Candidate: Decodable { let content: Content }
struct Content: Decodable { let parts: [Part] }
struct Part: Decodable { let text: String? }
