import Foundation

struct MockAIProvider: AIProvider {
    let id = "mock"

    func complete(_ request: AIRequest) async throws -> AIResponse {
        var text = ""
        for try await chunk in stream(request) {
            text += chunk.text
        }
        return AIResponse(text: text, providerID: id)
    }

    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let userText = request.messages.last(where: { $0.role == .user })?.content ?? ""
                if let refusal = AISafety.shouldRefuse(userText) {
                    continuation.yield(AIChunk(text: refusal, isFinal: true))
                    continuation.finish()
                    return
                }

                let phaseHint: String = {
                    guard let ctx = request.cycleContextJSON,
                          let data = ctx.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let phase = obj["phase"] as? String else {
                        return "your current cycle"
                    }
                    return "the \(phase) phase"
                }()

                let reply = """
                \(request.teenMode ? "Thanks for asking. " : "")Here's a general educational note about \(phaseHint): logging symptoms over a few cycles helps you notice your own patterns. \
                dawt is not medical advice or birth control. If something feels urgent or unusual for you, check in with a clinician.

                You asked: “\(userText.prefix(160))”
                """

                let words = reply.split(separator: " ")
                for (index, word) in words.enumerated() {
                    try await Task.sleep(nanoseconds: 25_000_000)
                    let piece = String(word) + (index == words.count - 1 ? "" : " ")
                    continuation.yield(AIChunk(text: piece, isFinal: index == words.count - 1))
                }
                continuation.finish()
            }
        }
    }
}
