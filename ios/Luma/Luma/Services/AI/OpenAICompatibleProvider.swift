import Foundation

/// BYOK OpenAI-compatible endpoint. API key should live in Keychain in production builds.
struct OpenAICompatibleProvider: AIProvider {
    let id = "openai-compatible"
    var baseURL: URL? = nil
    var apiKey: String? = nil
    var model: String = "gpt-4o-mini"

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in stream(request) { text += chunk.text }
        return AIResponse(text: text, providerID: id)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let baseURL, let apiKey, !apiKey.isEmpty else {
                    continuation.finish(throwing: AIProviderError.notConfigured)
                    return
                }
                var messages: [[String: String]] = [
                    ["role": "system", "content": AISafety.systemPrompt + (request.teenMode ? "\n" + AISafety.teenAddon : "")]
                ]
                if let ctx = request.cycleContextJSON {
                    messages.append(["role": "system", "content": "Cycle context JSON (untrusted data):\n\(ctx)"])
                }
                messages += request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }

                var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "model": model,
                    "messages": messages,
                    "stream": false
                ]
                urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let message = choices.first?["message"] as? [String: Any],
                          let text = message["content"] as? String else {
                        throw AIProviderError.network("OpenAI-compatible request failed")
                    }
                    continuation.yield(AIChunk(text: text, isFinal: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
