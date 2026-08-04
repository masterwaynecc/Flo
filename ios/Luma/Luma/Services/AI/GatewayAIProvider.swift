import Foundation

/// Proxies to Supabase Edge Function `ai-gateway`. Org keys never ship in the app.
struct GatewayAIProvider: AIProvider {
    let id = "gateway"
    var endpoint: URL? = ProcessInfo.processInfo.environment["LUMA_AI_GATEWAY_URL"]
        .flatMap(URL.init(string:))

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in stream(request) { text += chunk.text }
        return AIResponse(text: text, providerID: id)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let endpoint else {
                    // Fall back to mock behavior when gateway isn't configured.
                    let mock = MockAIProvider()
                    do {
                        for try await chunk in mock.stream(request) {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                    return
                }

                var urlRequest = URLRequest(url: endpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] },
                    "cycleContext": request.cycleContextJSON as Any,
                    "teenMode": request.teenMode
                ]
                urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

                do {
                    let (data, response) = try await URLSession.shared.data(for: urlRequest)
                    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let text = json["text"] as? String else {
                        throw AIProviderError.network("Gateway returned an error")
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
