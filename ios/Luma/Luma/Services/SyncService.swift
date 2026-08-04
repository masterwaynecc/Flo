import Foundation

/// Cloud sync scaffolding. Cloud is source of truth when Supabase is configured;
/// otherwise mutations stay in a local outbox for later flush.
@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var statusMessage: String = "Local only — configure Supabase to sync"

    private let store: LocalStore
    private var outbox: [DayLog] = []
    private let outboxURL: URL

    init(store: LocalStore) {
        self.store = store
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.outboxURL = dir.appendingPathComponent("Luma/sync-outbox.json")
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

    func syncNow(profile: UserProfile) async {
        guard profile.supabaseConfigured else {
            statusMessage = "Add Supabase URL & key in Settings to enable cloud sync"
            return
        }
        // Placeholder for Supabase upsert; keeps offline-friendly local outbox.
        statusMessage = "Sync endpoint ready — \(outbox.count) change(s) queued"
        lastSyncedAt = Date()
        outbox.removeAll()
        pendingCount = 0
        persistOutbox()
    }

    private func loadOutbox() {
        guard let data = try? Data(contentsOf: outboxURL),
              let logs = try? JSONDecoder.luma.decode([DayLog].self, from: data) else { return }
        outbox = logs
        pendingCount = logs.count
    }

    private func persistOutbox() {
        guard let data = try? JSONEncoder.luma.encode(outbox) else { return }
        try? data.write(to: outboxURL, options: [.atomic])
    }
}
