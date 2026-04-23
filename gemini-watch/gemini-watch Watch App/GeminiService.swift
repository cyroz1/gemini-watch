import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case badURL

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "No API key found. Add GEMINI_API_KEY to Secrets.plist."
        case .badURL:        return "Invalid request URL."
        }
    }
}

actor GeminiService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/"

    /// Nil when the key is absent — callers receive a descriptive error instead of a crash. (#1)
    private let apiKey: String?

    init() {
        if let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: filePath),
           let value = plist.object(forKey: "GEMINI_API_KEY") as? String,
           !value.isEmpty {
            apiKey = value
        } else {
            apiKey = nil
        }
    }

    // MARK: - Streaming

    func streamGenerateContent(
        messages: [Message],
        model: String = "gemini-2.5-flash",
        systemPrompt: String = AppSettings.defaultSystemPrompt,
        temperature: Double = 0.7
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                guard let key = apiKey else {
                    continuation.finish(throwing: GeminiError.missingAPIKey)
                    return
                }

                let urlString = "\(baseURL)\(model):streamGenerateContent?key=\(key)&alt=sse"
                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: GeminiError.badURL)
                    return
                }

                // Build a properly alternating user↔model context (#2):
                // Strip any leading model messages, then ensure strict alternation.
                var contextMessages = Array(messages.suffix(20))
                // Drop leading model turns
                while contextMessages.first?.role == .model {
                    contextMessages.removeFirst()
                }
                // Ensure strict alternation: keep last of consecutive same-role messages
                var deduped: [Message] = []
                for msg in contextMessages {
                    if deduped.last?.role == msg.role {
                        deduped[deduped.count - 1] = msg
                    } else {
                        deduped.append(msg)
                    }
                }
                contextMessages = deduped

                let geminiRequest = GeminiRequest(
                    contents: contextMessages.map { message in
                        Content(role: message.role.rawValue, parts: [Part(text: message.text)])
                    },
                    system_instruction: Content(role: "system", parts: [
                        Part(text: systemPrompt)
                    ]),
                    generationConfig: GenerationConfig(temperature: temperature)
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
        guard let key = apiKey else { throw GeminiError.missingAPIKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.badURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "Gemini", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"])
        }

        let decoded = try JSONDecoder().decode(ModelsListResponse.self, from: data)

        // Filter to text-only Gemini models (excludes imagen, embedding, aqa, etc.)
        return decoded.models
            .filter { model in
                model.name.hasPrefix("models/gemini-") &&
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
    let generationConfig: GenerationConfig?
}

private struct GenerationConfig: Codable, Sendable {
    let temperature: Double
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
