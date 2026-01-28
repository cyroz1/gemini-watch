import Foundation

actor GeminiService {
    private let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent"
    
    private var apiKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: filePath),
              let value = plist.object(forKey: "GEMINI_API_KEY") as? String else {
            fatalError("Couldn't find key 'GEMINI_API_KEY' in 'Secrets.plist'.")
        }
        return value
    }
    
    func streamGenerateContent(messages: [Message]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "\(urlString)?key=\(apiKey)&alt=sse") else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }
                
                let geminiRequest = GeminiRequest(
                    contents: messages.map { message in
                        Content(role: message.role.rawValue, parts: [Part(text: message.text)])
                    },
                    system_instruction: Content(role: "system", parts: [
                        Part(text: "You are a helpful and conversational AI assistant. Be concise, friendly, and use markdown formatting (bolding, lists) when appropriate to make information easier to read on a small screen.")
                    ])
                )
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                do {
                    request.httpBody = try JSONEncoder().encode(geminiRequest)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        // Attempt to read the error body
                        let errorText = "Server returned error: \(httpResponse.statusCode)"
                        // We can't easily read the stream body here without consuming it as data, 
                        // but bytes.lines might give us a hint if we iterate.
                        // For now, simpler error is safer.
                        continuation.finish(throwing: NSError(domain: "Gemini", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText]))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                            // The stream might send "data: [DONE]" or similar in some APIs, 
                            // but Gemini sends valid JSON or nothing.
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                                if let text = decoded.candidates?.first?.content.parts.first?.text {
                                    continuation.yield(text)
                                }
                            } catch {
                                // Sometimes empty keep-alive lines or metadata might parse poorly, ignore singular parse errors in stream
                                print("Parse error: \(error)") 
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

// MARK: - API Models

private struct GeminiRequest: Codable, Sendable {
    let contents: [Content]
    let system_instruction: Content?
}

// Reuse Content/Part but make them conform to Codable for both Request and Response
// Since we used slightly different structures in the original file, let's standardize here.

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
