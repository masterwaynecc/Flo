
import Foundation

public struct AIMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var role: Role
    public var content: String
    public var createdAt: Date

    public enum Role: String, Codable, Sendable {
        case system, user, assistant
    }

    public init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

public enum AISafety {
    public static let systemPrompt = """
    You are Luma Health Assistant, an educational companion for menstrual cycle health.
    You do not diagnose, prescribe, or provide emergency care. You are not contraception advice.
    If the user describes an emergency, urge them to seek emergency services.
    Keep answers concise, compassionate, and evidence-informed at a general education level.
    """

    public static let teenAddon = """
    Teen mode is on: use age-appropriate language, avoid explicit sexual detail, encourage talking to a trusted adult or clinician for medical concerns.
    """

    public static func shouldRefuse(_ text: String) -> String? {
        let lower = text.lowercased()
        let emergency = ["chest pain", "can't breathe", "suicidal", "kill myself", "severe bleeding", "passed out"]
        if emergency.contains(where: { lower.contains($0) }) {
            return "I'm concerned about your safety. Please contact local emergency services or a trusted clinician right away. Luma can't help in emergencies."
        }
        return nil
    }
}
