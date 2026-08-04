import Foundation

enum LifeStageGoal: String, Codable, CaseIterable, Identifiable {
    case track
    case ttc
    case pregnant
    case perimenopause

    var id: String { rawValue }

    var title: String {
        switch self {
        case .track: return "Track my cycle"
        case .ttc: return "Trying to conceive"
        case .pregnant: return "I'm pregnant"
        case .perimenopause: return "Perimenopause"
        }
    }

    var subtitle: String {
        switch self {
        case .track: return "Periods, symptoms, and predictions"
        case .ttc: return "Fertile window and ovulation focus"
        case .pregnant: return "Week-by-week pregnancy mode"
        case .perimenopause: return "Changing cycles and symptoms"
        }
    }
}

enum FlowLevel: String, Codable, CaseIterable, Identifiable {
    case none, spotting, light, medium, heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }

    var isPeriod: Bool { self != .none }
}

enum CyclePhase: String, Codable {
    case menstrual, follicular, fertile, ovulation, luteal, unknown

    var title: String {
        switch self {
        case .menstrual: return "Period"
        case .follicular: return "Follicular"
        case .fertile: return "Fertile window"
        case .ovulation: return "Ovulation"
        case .luteal: return "Luteal"
        case .unknown: return "Getting to know you"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var hasCompletedOnboarding: Bool = false
    var disclaimerAccepted: Bool = false
    var goal: LifeStageGoal = .track
    var lastPeriodStart: Date?
    var typicalCycleLength: Int = 28
    var typicalPeriodLength: Int = 5
    var teenMode: Bool = false
    var aiContextConsent: Bool = false
    var aiProviderPreference: AIProviderKind = .mock
    var remindersEnabled: Bool = true
    var displayName: String = ""
    var supabaseConfigured: Bool = false
}

struct DayLog: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var flow: FlowLevel
    var symptomIDs: [String]
    var moodIDs: [String]
    var notes: String
    var updatedAt: Date
    var clientId: UUID

    init(
        id: UUID = UUID(),
        date: Date,
        flow: FlowLevel = .none,
        symptomIDs: [String] = [],
        moodIDs: [String] = [],
        notes: String = "",
        updatedAt: Date = Date(),
        clientId: UUID = UUID()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.flow = flow
        self.symptomIDs = symptomIDs
        self.moodIDs = moodIDs
        self.notes = notes
        self.updatedAt = updatedAt
        self.clientId = clientId
    }
}

struct CyclePrediction: Equatable {
    var cycleDay: Int
    var phase: CyclePhase
    var cycleLength: Int
    var periodLength: Int
    var nextPeriodStart: Date?
    var fertileWindow: ClosedRange<Date>?
    var ovulationDay: Date?
    var algorithmVersion: String
    var confidenceNote: String
}

struct DailyInsight: Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var source: InsightSource
}

enum InsightSource: String, Equatable {
    case template
    case ai
}

struct OnboardingDraft {
    var goal: LifeStageGoal = .track
    var lastPeriodStart: Date = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
    var cycleLength: Int = 28
    var periodLength: Int = 5
    var teenMode: Bool = false
    var acceptedDisclaimer: Bool = false
}

struct CatalogItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var category: String
    var sfSymbol: String
}

enum AIProviderKind: String, Codable, CaseIterable, Identifiable {
    case mock
    case gateway
    case ollama
    case selfHosted
    case appleOnDevice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mock: return "Built-in (offline demo)"
        case .gateway: return "dawt gateway (open-weight)"
        case .ollama: return "Ollama (local open-weight)"
        case .selfHosted: return "Self-hosted open-weight"
        case .appleOnDevice: return "Apple on-device"
        }
    }
}
