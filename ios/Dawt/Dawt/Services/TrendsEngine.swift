import Foundation

struct CycleLengthPoint: Identifiable, Equatable {
    var id: String { "\(start.timeIntervalSince1970)" }
    var start: Date
    var length: Int
}

struct SymptomTrend: Identifiable, Equatable {
    var id: String { symptomID }
    var symptomID: String
    var title: String
    var count: Int
}

struct FlowDayPoint: Identifiable, Equatable {
    var id: String { "\(date.timeIntervalSince1970)" }
    var date: Date
    var intensity: Int
}

struct TrendsReport: Equatable {
    var cycleLengths: [CycleLengthPoint]
    var averageCycleLength: Int?
    var flowLast60: [FlowDayPoint]
    var topSymptoms: [SymptomTrend]
    var loggedDays: Int
    var periodDays: Int
}

struct TrendsEngine {
    func report(logs: [DayLog], catalogTitles: [String: String] = [:]) -> TrendsReport {
        let starts = periodStarts(from: logs)
        var lengths: [CycleLengthPoint] = []
        if starts.count >= 2 {
            for i in 1..<starts.count {
                let days = Calendar.current.dateComponents([.day], from: starts[i - 1], to: starts[i]).day ?? 0
                if days > 0 && days < 60 {
                    lengths.append(CycleLengthPoint(start: starts[i], length: days))
                }
            }
        }

        let avg: Int? = lengths.isEmpty
            ? nil
            : Int((Double(lengths.map(\.length).reduce(0, +)) / Double(lengths.count)).rounded())

        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date.distantPast
        let flowPoints = logs
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
            .map { FlowDayPoint(date: $0.date, intensity: flowIntensity($0.flow)) }

        var counts: [String: Int] = [:]
        for log in logs {
            for id in log.symptomIDs {
                counts[id, default: 0] += 1
            }
        }
        let top = counts
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map {
                SymptomTrend(
                    symptomID: $0.key,
                    title: catalogTitles[$0.key] ?? $0.key.replacingOccurrences(of: "_", with: " ").capitalized,
                    count: $0.value
                )
            }

        return TrendsReport(
            cycleLengths: lengths,
            averageCycleLength: avg,
            flowLast60: flowPoints,
            topSymptoms: Array(top),
            loggedDays: logs.count,
            periodDays: logs.filter { $0.flow.isPeriod }.count
        )
    }

    private func flowIntensity(_ flow: FlowLevel) -> Int {
        switch flow {
        case .none: return 0
        case .spotting: return 1
        case .light: return 2
        case .medium: return 3
        case .heavy: return 4
        }
    }

    private func periodStarts(from logs: [DayLog]) -> [Date] {
        let cal = Calendar.current
        let periodDays = logs
            .filter(\.flow.isPeriod)
            .map { cal.startOfDay(for: $0.date) }
            .sorted()
        var starts: [Date] = []
        var previous: Date?
        for day in periodDays {
            if let previous {
                let gap = cal.dateComponents([.day], from: previous, to: day).day ?? 0
                if gap > 1 {
                    starts.append(day)
                }
            } else {
                starts.append(day)
            }
            previous = day
        }
        return starts
    }
}
