import Foundation

public enum LifeStageGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case track, ttc, pregnant, perimenopause
    public var id: String { rawValue }
}

public enum FlowLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, spotting, light, medium, heavy
    public var id: String { rawValue }
    public var isPeriod: Bool { self != .none }
}

public enum CyclePhase: String, Codable, Sendable {
    case menstrual, follicular, fertile, ovulation, luteal, unknown
}

public struct UserProfile: Codable, Equatable, Sendable {
    public var hasCompletedOnboarding: Bool = false
    public var disclaimerAccepted: Bool = false
    public var goal: LifeStageGoal = .track
    public var lastPeriodStart: Date?
    public var typicalCycleLength: Int = 28
    public var typicalPeriodLength: Int = 5
    public var teenMode: Bool = false
    public var aiContextConsent: Bool = false
    public var aiProviderPreference: AIProviderKind = .mock
    public var remindersEnabled: Bool = true
    public var displayName: String = ""
    public var supabaseConfigured: Bool = false

    public init() {}
}

public struct DayLog: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var flow: FlowLevel
    public var symptomIDs: [String]
    public var moodIDs: [String]
    public var notes: String
    public var updatedAt: Date
    public var clientId: UUID

    public init(
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

public struct CyclePrediction: Equatable, Sendable {
    public var cycleDay: Int
    public var phase: CyclePhase
    public var cycleLength: Int
    public var periodLength: Int
    public var nextPeriodStart: Date?
    public var fertileWindow: ClosedRange<Date>?
    public var ovulationDay: Date?
    public var algorithmVersion: String
    public var confidenceNote: String

    public init(
        cycleDay: Int,
        phase: CyclePhase,
        cycleLength: Int,
        periodLength: Int,
        nextPeriodStart: Date?,
        fertileWindow: ClosedRange<Date>?,
        ovulationDay: Date?,
        algorithmVersion: String,
        confidenceNote: String
    ) {
        self.cycleDay = cycleDay
        self.phase = phase
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.nextPeriodStart = nextPeriodStart
        self.fertileWindow = fertileWindow
        self.ovulationDay = ovulationDay
        self.algorithmVersion = algorithmVersion
        self.confidenceNote = confidenceNote
    }
}

public struct DailyInsight: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var source: InsightSource

    public init(id: String, title: String, body: String, source: InsightSource) {
        self.id = id
        self.title = title
        self.body = body
        self.source = source
    }
}

public enum InsightSource: String, Equatable, Sendable {
    case template, ai
}

public struct CatalogItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var category: String
    public var sfSymbol: String

    public init(id: String, title: String, category: String, sfSymbol: String) {
        self.id = id
        self.title = title
        self.category = category
        self.sfSymbol = sfSymbol
    }
}

public enum AIProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case mock, gateway, ollama, selfHosted, appleOnDevice
    public var id: String { rawValue }
}
