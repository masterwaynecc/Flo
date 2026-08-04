import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var profile: UserProfile
    @Published var dayLogs: [DayLog]
    @Published var selectedTab: AppTab = .today
    @Published var showingDayLog: Bool = false
    @Published var dayLogDate: Date = Date()
    @Published var showingAssistant: Bool = false

    let store: LocalStore
    let predictionEngine: CyclePredictionEngine
    let insightEngine: InsightEngine
    let syncService: SyncService
    let aiRouter: AIRouter

    init(store: LocalStore = LocalStore()) {
        self.store = store
        self.predictionEngine = CyclePredictionEngine()
        self.insightEngine = InsightEngine()
        self.syncService = SyncService(store: store)
        self.aiRouter = AIRouter()

        let loaded = store.load()
        self.hasCompletedOnboarding = loaded.profile.hasCompletedOnboarding
        self.profile = loaded.profile
        self.dayLogs = loaded.dayLogs
    }

    var prediction: CyclePrediction {
        predictionEngine.predict(profile: profile, logs: dayLogs, asOf: Date())
    }

    var todayInsight: DailyInsight {
        insightEngine.insight(for: prediction, profile: profile, logs: dayLogs)
    }

    func completeOnboarding(_ draft: OnboardingDraft) {
        profile.goal = draft.goal
        profile.lastPeriodStart = draft.lastPeriodStart
        profile.typicalCycleLength = draft.cycleLength
        profile.typicalPeriodLength = draft.periodLength
        profile.teenMode = draft.teenMode
        profile.disclaimerAccepted = true
        profile.hasCompletedOnboarding = true
        hasCompletedOnboarding = true

        if let start = draft.lastPeriodStart {
            seedPeriodDays(from: start, length: draft.periodLength)
        }
        persist()
        Task { await requestNotificationPermissionIfNeeded() }
    }

    func upsertDayLog(_ log: DayLog) {
        if let idx = dayLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: log.date) }) {
            dayLogs[idx] = log
        } else {
            dayLogs.append(log)
            dayLogs.sort { $0.date < $1.date }
        }
        persist()
        syncService.enqueue(log)
    }

    func logFor(date: Date) -> DayLog? {
        dayLogs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func openDayLog(for date: Date = Date()) {
        dayLogDate = Calendar.current.startOfDay(for: date)
        showingDayLog = true
    }

    func exportJSON() -> Data? {
        store.exportJSON(profile: profile, dayLogs: dayLogs)
    }

    func deleteAllLocalData() {
        store.clear()
        profile = UserProfile()
        dayLogs = []
        hasCompletedOnboarding = false
        persist()
    }

    func persist() {
        store.save(profile: profile, dayLogs: dayLogs)
    }

    private func seedPeriodDays(from start: Date, length: Int) {
        let cal = Calendar.current
        for offset in 0..<max(length, 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: start)) else { continue }
            var log = logFor(date: day) ?? DayLog(date: day)
            log.flow = offset == 0 ? .medium : (offset < length - 1 ? .light : .spotting)
            upsertDayLog(log)
        }
    }

    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        NotificationScheduler.reschedule(profile: profile, prediction: prediction)
    }
}

enum AppTab: Hashable {
    case today, calendar, insights, settings
}
