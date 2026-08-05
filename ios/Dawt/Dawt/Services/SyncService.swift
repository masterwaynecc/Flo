import Foundation

/// Cloud sync with local outbox. Cloud is source of truth when signed in;
/// mutations stay queued offline and flush when connectivity returns.
@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var statusMessage: String = "Local only — sign in to sync"
    @Published private(set) var isSyncing = false

    private let store: LocalStore
    private var outbox: [DayLog] = []
    private let outboxURL: URL

    init(store: LocalStore) {
        self.store = store
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("dawt", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.outboxURL = folder.appendingPathComponent("sync-outbox.json")
        loadOutbox()
    }

    func enqueue(_ log: DayLog) {
        if let idx = outbox.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: log.date) }) {
            outbox[idx] = log
        } else {
            outbox.append(log)
        }
        pendingCount = outbox.count
        persistOutbox()
    }

    func syncNow(
        session: SupabaseSession?,
        profile: UserProfile,
        prediction: CyclePrediction,
        allLogs: [DayLog]
    ) async -> [DayLog]? {
        guard let session else {
            statusMessage = "Sign in with Apple to enable cloud sync"
            return nil
        }
        guard SupabaseConfig.isConfigured else {
            statusMessage = "Supabase is not configured"
            return nil
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            try await SupabaseClient.shared.upsertProfile(session: session, profile: profile)
            let pushLogs = outbox.isEmpty ? allLogs : outbox
            try await SupabaseClient.shared.upsertDayLogs(session: session, logs: pushLogs)
            try await SupabaseClient.shared.upsertShareSnapshot(
                session: session,
                prediction: prediction,
                profile: profile,
                logs: allLogs
            )
            let remote = try await SupabaseClient.shared.fetchDayLogs(session: session)
            outbox.removeAll()
            pendingCount = 0
            persistOutbox()
            lastSyncedAt = Date()
            statusMessage = "Synced \(remote.count) day(s)"
            return remote
        } catch {
            statusMessage = error.localizedDescription
            return nil
        }
    }

    private func loadOutbox() {
        guard let data = try? Data(contentsOf: outboxURL),
              let logs = try? JSONDecoder.dawt.decode([DayLog].self, from: data) else { return }
        outbox = logs
        pendingCount = logs.count
    }

    private func persistOutbox() {
        guard let data = try? JSONEncoder.dawt.encode(outbox) else { return }
        try? data.write(to: outboxURL, options: [.atomic])
    }
}
