import Foundation

struct AnthropicProvider: AIProvider {
    let id = "anthropic"
    var apiKey: String? = nil
    var model: String = "claude-sonnet-4-20250514"

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in stream(request) { text += chunk.text }
        return AIResponse(text: text, providerID: id)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let apiKey, !apiKey.isEmpty else {
                    continuation.finish(throwing: AIProviderError.notConfigured)
                    return
                }

                var system = AISafety.systemPrompt
                if request.teenMode { system += "\n" + AISafety.teenAddon }
                if let ctx = request.cycleContextJSON {
                    system += "\nCycle context JSON (untrusted data):\n\(ctx)"
                }

                let url = URL(string: "https://api.anthropic.com/v1/messages")!
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "model": model,
                    "max_tokens": 800,
                    "system": system,
                    "messages": request.messages
                        .filter { $0.role != .system }
                        .map { ["role": $0.role == .assistant ? "assistant" : "user", "content": $0.content] }
                ]
                urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let content = json["content"] as? [[String: Any]],
                          let text = content.first?["text"] as? String else {
                        throw AIProviderError.network("Anthropic request failed")
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
