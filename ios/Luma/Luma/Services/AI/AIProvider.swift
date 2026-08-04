import Foundation

struct AIMessage: Codable, Equatable, Identifiable {
    var id: UUID
    var role: Role
    var content: String
    var createdAt: Date

    enum Role: String, Codable {
        case system, user, assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct AIRequest: Sendable {
    var messages: [AIMessage]
    var cycleContextJSON: String?
    var teenMode: Bool
    var stream: Bool
}

struct AIResponse: Sendable {
    var text: String
    var providerID: String
}

struct AIChunk: Sendable {
    var text: String
    var isFinal: Bool
}

protocol AIProvider: Sendable {
    var id: String { get }
    func complete(_ request: AIRequest) async throws -> AIResponse
    func stream(_ request: AIRequest) -> AsyncThrowingStream<AIChunk, Error>
}

enum AIProviderError: LocalizedError {
    case notConfigured
    case network(String)
    case refused(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "This AI provider is not configured yet."
        case .network(let message): return message
        case .refused(let message): return message
        }
    }
}

@MainActor
final class AIRouter: ObservableObject {
    @Published var selected: AIProviderKind = .mock

    private let mock = MockAIProvider()
    private let gateway = GatewayAIProvider()
    private let openAI = OpenAICompatibleProvider()
    private let anthropic = AnthropicProvider()
    private let apple = AppleOnDeviceProvider()

    func provider(for kind: AIProviderKind) -> any AIProvider {
        switch kind {
        case .mock: return mock
        case .gateway: return gateway
        case .openAICompatible: return openAI
        case .anthropic: return anthropic
        case .appleOnDevice: return apple
        }
    }

    func stream(messages: [AIMessage], profile: UserProfile, prediction: CyclePrediction, logs: [DayLog]) -> AsyncThrowingStream<AIChunk, Error> {
        let context: String?
        if profile.aiContextConsent {
            context = CycleContextBuilder.build(profile: profile, prediction: prediction, logs: logs)
        } else {
            context = nil
        }
        let request = AIRequest(
            messages: messages,
            cycleContextJSON: context,
            teenMode: profile.teenMode,
            stream: true
        )
        return provider(for: profile.aiProviderPreference).stream(request)
    }
}

enum CycleContextBuilder {
    static func build(profile: UserProfile, prediction: CyclePrediction, logs: [DayLog]) -> String {
        let recent = logs.sorted { $0.date > $1.date }.prefix(7).map { log in
            [
                "date": ISO8601DateFormatter().string(from: log.date),
                "flow": log.flow.rawValue,
                "symptoms": log.symptomIDs.joined(separator: ","),
                "moods": log.moodIDs.joined(separator: ",")
            ]
        }
        let payload: [String: Any] = [
            "goal": profile.goal.rawValue,
            "cycleDay": prediction.cycleDay,
            "phase": prediction.phase.rawValue,
            "cycleLength": prediction.cycleLength,
            "algorithmVersion": prediction.algorithmVersion,
            "recentLogs": recent
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
}

enum AISafety {
    static let systemPrompt = """
    You are Luma Health Assistant, an educational companion for menstrual cycle health.
    You do not diagnose, prescribe, or provide emergency care. You are not contraception advice.
    If the user describes an emergency, urge them to seek emergency services.
    Keep answers concise, compassionate, and evidence-informed at a general education level.
    """

    static let teenAddon = """
    Teen mode is on: use age-appropriate language, avoid explicit sexual detail, encourage talking to a trusted adult or clinician for medical concerns.
    """

    static func shouldRefuse(_ text: String) -> String? {
        let lower = text.lowercased()
        let emergency = ["chest pain", "can't breathe", "suicidal", "kill myself", "severe bleeding", "passed out"]
        if emergency.contains(where: { lower.contains($0) }) {
            return "I'm concerned about your safety. Please contact local emergency services or a trusted clinician right away. Luma can't help in emergencies."
        }
        return nil
    }
}
