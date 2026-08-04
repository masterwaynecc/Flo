import Foundation

/// Placeholder for Apple Foundation Models / on-device generation when available.
struct AppleOnDeviceProvider: AIProvider {
    let id = "apple-on-device"

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in stream(request) { text += chunk.text }
        return AIResponse(text: text, providerID: id)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error> {
        // Until Foundation Models APIs are wired, reuse the offline mock with a clear label.
        let mock = MockAIProvider()
        return AsyncThrowingStream { continuation in
            Task {
                continuation.yield(AIChunk(text: "(On-device path) ", isFinal: false))
                do {
                    for try await chunk in mock.stream(request) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
