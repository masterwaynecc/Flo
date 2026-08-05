import Combine
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

    let store: LocalStore
    let predictionEngine: CyclePredictionEngine
    let insightEngine: InsightEngine
    let syncService: SyncService
    let aiRouter: AIRouter
    let authService: AuthService
    let partnerService: PartnerService
    private var cancellables = Set<AnyCancellable>()

    init(store: LocalStore = LocalStore()) {
        self.store = store
        self.predictionEngine = CyclePredictionEngine()
        self.insightEngine = InsightEngine()
        self.syncService = SyncService(store: store)
        self.aiRouter = AIRouter()
        self.authService = AuthService()
        self.partnerService = PartnerService()

        let loaded = store.load()
        self.hasCompletedOnboarding = loaded.profile.hasCompletedOnboarding
        self.profile = loaded.profile
        self.dayLogs = loaded.dayLogs

        if SupabaseConfig.isConfigured {
            profile.supabaseConfigured = true
        }

        authService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        partnerService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        syncService.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var prediction: CyclePrediction {
        predictionEngine.predict(profile: profile, logs: dayLogs, asOf: Date())
    }

    var todayInsight: DailyInsight {
        insightEngine.insight(for: prediction, profile: profile, logs: dayLogs)
    }

    func bootstrap() async {
        clearFuturePeriodLogs()
        await authService.restoreSession()
        applyPendingDisplayName()
        if authService.isSignedIn {
            await syncFromCloud()
            await partnerService.refresh(session: authService.session)
        }
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

        seedPeriodDays(from: draft.lastPeriodStart, length: draft.periodLength)
        persist()
        Task {
            await requestNotificationPermissionIfNeeded()
            await syncFromCloud()
        }
    }

    func upsertDayLog(_ log: DayLog, sync: Bool = true) {
        if let idx = dayLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: log.date) }) {
            dayLogs[idx] = log
        } else {
            dayLogs.append(log)
            dayLogs.sort { $0.date < $1.date }
        }
        persist()
        syncService.enqueue(log)
        if sync {
            Task { await syncFromCloud() }
        }
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
        if SupabaseConfig.isConfigured {
            profile.supabaseConfigured = true
        }
        persist()
    }

    func persist() {
        store.save(profile: profile, dayLogs: dayLogs)
    }

    func signInWithApple() async {
        await authService.signInWithApple()
        applyPendingDisplayName()
        if authService.isSignedIn {
            profile.supabaseConfigured = true
            persist()
            await syncFromCloud()
            await partnerService.refresh(session: authService.session)
        }
    }

    func signOut() async {
        await authService.signOut()
        await partnerService.refresh(session: nil)
    }

    func syncFromCloud() async {
        guard let remote = await syncService.syncNow(
            session: authService.session,
            profile: profile,
            prediction: prediction,
            allLogs: dayLogs
        ) else { return }

        dayLogs = mergeLogs(local: dayLogs, remote: remote)
        if let latestPeriod = dayLogs.filter(\.flow.isPeriod).map(\.date).max() {
            profile.lastPeriodStart = latestPeriodStart(from: dayLogs) ?? latestPeriod
        }
        persist()
        await partnerService.refresh(session: authService.session)
    }

    private func applyPendingDisplayName() {
        if let name = UserDefaults.standard.string(forKey: "dawt.pending.displayName"), !name.isEmpty {
            profile.displayName = name
            UserDefaults.standard.removeObject(forKey: "dawt.pending.displayName")
            persist()
        }
    }

    private func mergeLogs(local: [DayLog], remote: [DayLog]) -> [DayLog] {
        var map: [String: DayLog] = [:]
        let key: (DayLog) -> String = {
            let f = DateFormatter()
            f.calendar = Calendar.current
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = Calendar.current.timeZone
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Calendar.current.startOfDay(for: $0.date))
        }
        for log in remote { map[key(log)] = log }
        for log in local {
            let k = key(log)
            if let existing = map[k] {
                // Keep newer content, but prefer the remote primary key after a sync.
                if log.updatedAt > existing.updatedAt {
                    var merged = log
                    merged.id = existing.id
                    map[k] = merged
                }
            } else {
                map[k] = log
            }
        }
        return map.values.sorted { $0.date < $1.date }
    }

    private func latestPeriodStart(from logs: [DayLog]) -> Date? {
        let cal = Calendar.current
        let periodDays = logs.filter(\.flow.isPeriod).map { cal.startOfDay(for: $0.date) }.sorted()
        var starts: [Date] = []
        var previous: Date?
        for day in periodDays {
            if let previous {
                let gap = cal.dateComponents([.day], from: previous, to: day).day ?? 0
                if gap > 1 { starts.append(day) }
            } else {
                starts.append(day)
            }
            previous = day
        }
        return starts.last
    }

    private func seedPeriodDays(from start: Date, length: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDay = cal.startOfDay(for: start)
        for offset in 0..<max(length, 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDay) else { continue }
            // Only seed days that have already happened — remaining period days stay predictions.
            guard day <= today else { break }
            var log = logFor(date: day) ?? DayLog(date: day)
            log.flow = offset == 0 ? .medium : (offset < length - 1 ? .light : .spotting)
            upsertDayLog(log, sync: false)
        }
    }

    /// Onboarding used to pre-log the full period length into the future; strip those so they show as predictions.
    private func clearFuturePeriodLogs() {
        let today = Calendar.current.startOfDay(for: Date())
        var changed = false
        for idx in dayLogs.indices where dayLogs[idx].date > today && dayLogs[idx].flow.isPeriod {
            dayLogs[idx].flow = .none
            dayLogs[idx].updatedAt = Date()
            syncService.enqueue(dayLogs[idx])
            changed = true
        }
        if changed { persist() }
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
