import Foundation

actor GeminiService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/"
    
    private var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist.object(forKey: "GEMINI_API_KEY") as? String else {
            fatalError("Couldn't find key 'GEMINI_API_KEY' in 'Secrets.plist'.")
        }
        return value
    }
    
    func streamGenerateContent(messages: [Message], model: String = "gemini-2.5-flash", systemPrompt: String = AppSettings.defaultSystemPrompt) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let urlString = "\(baseURL)\(model):streamGenerateContent?key=\(apiKey)&alt=sse"
                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                
                let geminiRequest = GeminiRequest(
                    contents: messages.map { message in
                        Content(role: message.role.rawValue, parts: [Part(text: message.text)])
                    },
                    system_instruction: Content(role: "system", parts: [
                        Part(text: systemPrompt)
                    ])
                )
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 20
                
                do {
                    request.httpBody = try JSONEncoder().encode(geminiRequest)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        let code = httpResponse.statusCode
                        let detail: String
                        switch code {
                        case 429: detail = "Rate limited. Wait a moment."
                        case 401, 403: detail = "API key invalid."
                        case 500...599: detail = "Server error. Try again."
                        default: detail = "Error \(code)"
                        }
                        continuation.finish(throwing: NSError(domain: "Gemini", code: code, userInfo: [NSLocalizedDescriptionKey: detail]))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        if line.hasPrefix("data: ") {
                            let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                                if let text = decoded.candidates?.first?.content.parts.first?.text {
                                    continuation.yield(text)
                                }
                            } catch {
                                // Ignore parse errors on individual stream chunks
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        let msg = (error as? URLError)?.code == .timedOut
                            ? "Request timed out. Check connection."
                            : error.localizedDescription
                        continuation.finish(throwing: NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: msg]))
                    } else {
                        continuation.finish()
                    }
                }
            }
        }
    }
    
    // MARK: - List Available Models
    
    func listModels() async throws -> [String] {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "Gemini", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"])
        }
        
        let decoded = try JSONDecoder().decode(ModelsListResponse.self, from: data)
        
        // Filter to models that support generateContent and extract clean names
        return decoded.models
            .filter { model in
                model.supportedGenerationMethods?.contains("generateContent") == true
            }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }
            .sorted()
    }
}

// MARK: - API Models

private struct GeminiRequest: Codable, Sendable {
    let contents: [Content]
    let system_instruction: Content?
}

private struct GeminiResponse: Decodable, Sendable {
    let candidates: [Candidate]?
}

private struct Candidate: Decodable, Sendable {
    let content: Content
}

private struct Content: Codable, Sendable {
    var role: String?
    let parts: [Part]
}

private struct Part: Codable, Sendable {
    let text: String?
}

// MARK: - Models List API

struct ModelsListResponse: Decodable {
    let models: [ModelInfo]
}

struct ModelInfo: Decodable {
    let name: String
    let supportedGenerationMethods: [String]?
}
