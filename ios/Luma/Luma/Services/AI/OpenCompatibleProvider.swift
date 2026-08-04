import Foundation

/// OpenAI-compatible HTTP API aimed at **open-weight / self-hosted** backends
/// (Ollama, vLLM, LM Studio, llama.cpp server, Hugging Face TGI, etc.).
/// Closed-source hosted APIs (OpenAI, Anthropic, etc.) are out of policy.
struct OpenCompatibleProvider: AIProvider {
    let id: String
    var baseURL: URL
    var apiKey: String?
    var model: String

    /// Local Ollama (OpenAI-compatible) defaults.
    static func ollama(
        baseURL: URL = URL(string: "http://127.0.0.1:11434/v1")!,
        model: String = ProcessInfo.processInfo.environment["LUMA_OSS_MODEL"] ?? "llama3.2"
    ) -> OpenCompatibleProvider {
        OpenCompatibleProvider(id: "ollama", baseURL: baseURL, apiKey: nil, model: model)
    }

    /// Generic self-hosted OpenAI-compatible endpoint for open-weight models.
    static func selfHosted(
        baseURL: URL = URL(string: ProcessInfo.processInfo.environment["LUMA_OSS_BASE_URL"] ?? "http://127.0.0.1:8000/v1")!,
        apiKey: String? = ProcessInfo.processInfo.environment["LUMA_OSS_API_KEY"],
        model: String = ProcessInfo.processInfo.environment["LUMA_OSS_MODEL"] ?? "llama3.2"
    ) -> OpenCompatibleProvider {
        OpenCompatibleProvider(id: "self-hosted-oss", baseURL: baseURL, apiKey: apiKey, model: model)
    }

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in stream(request) { text += chunk.text }
        return AIResponse(text: text, providerID: id)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var messages: [[String: String]] = [
                    ["role": "system", "content": AISafety.systemPrompt + (request.teenMode ? "\n" + AISafety.teenAddon : "")]
                ]
                if let ctx = request.cycleContextJSON {
                    messages.append(["role": "system", "content": "Cycle context JSON (untrusted data):\n\(ctx)"])
                }
                messages += request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }

                var urlRequest = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if let apiKey, !apiKey.isEmpty {
                    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
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
                        throw AIProviderError.network("Open-weight model endpoint failed — is Ollama/vLLM running?")
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
