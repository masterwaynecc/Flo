import Foundation

struct PersistedState: Codable {
    var profile: UserProfile
    var dayLogs: [DayLog]
}

final class LocalStore: @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "app.dawt.localstore")

    init(filename: String = "dawt-state.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Dawt", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent(filename)
    }

    func load() -> PersistedState {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? JSONDecoder.dawt.decode(PersistedState.self, from: data) else {
                return PersistedState(profile: UserProfile(), dayLogs: [])
            }
            return state
        }
    }

    func save(profile: UserProfile, dayLogs: [DayLog]) {
        queue.sync {
            let state = PersistedState(profile: profile, dayLogs: dayLogs)
            guard let data = try? JSONEncoder.dawt.encode(state) else { return }
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func exportJSON(profile: UserProfile, dayLogs: [DayLog]) -> Data? {
        let payload: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "profile": [
                "goal": profile.goal.rawValue,
                "typicalCycleLength": profile.typicalCycleLength,
                "typicalPeriodLength": profile.typicalPeriodLength,
                "teenMode": profile.teenMode
            ],
            "dayLogs": dayLogs.map { log in
                [
                    "date": ISO8601DateFormatter().string(from: log.date),
                    "flow": log.flow.rawValue,
                    "symptoms": log.symptomIDs,
                    "moods": log.moodIDs,
                    "notes": log.notes
                ]
            }
        ]
        return try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }
}

extension JSONEncoder {
    static let dawt: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let dawt: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
