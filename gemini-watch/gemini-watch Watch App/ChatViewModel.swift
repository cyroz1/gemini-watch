import Foundation
import SwiftUI
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // 🔑 REPLACE THIS WITH YOUR REAL API KEY
    private let apiKey = "YOUR_API_KEY_HERE"
    
    // API Endpoint for Gemini 1.5 Flash (Fast & Cheap)
    private let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    @Published var messages: [(role: String, text: String)] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func sendMessage(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Add user message to UI
        messages.append((role: "user", text: text))
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let responseText = try await sendToGemini(prompt: text)
                messages.append((role: "model", text: responseText))
            } catch {
                errorMessage = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    // Raw Networking Code (No SDK needed)
    private func sendToGemini(prompt: String) async throws -> String {
        guard let url = URL(string: "\(urlString)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        
        let body: [String: Any] = [
            "contents": [
                [ "parts": [ ["text": prompt] ] ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Decode the response
        let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return decodedResponse.candidates?.first?.content.parts.first?.text ?? "No response."
    }
}

// Data Structures for JSON Decoding
struct GeminiResponse: Decodable {
    let candidates: [Candidate]?
}
struct Candidate: Decodable {
    let content: Content
}
struct Content: Decodable {
    let parts: [Part]
}
struct Part: Decodable {
    let text: String?
}
