import Foundation

/// Stateless prediction engine. Algorithm version is stamped on each result.
struct CyclePredictionEngine: Sendable {
    static let algorithmVersion = "dawt-avg-v1"

    func predict(profile: UserProfile, logs: [DayLog], asOf date: Date = Date()) -> CyclePrediction {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        let periodStarts = detectPeriodStarts(from: logs)
        let cycleLength = averageCycleLength(starts: periodStarts, fallback: profile.typicalCycleLength)
        let periodLength = averagePeriodLength(logs: logs, fallback: profile.typicalPeriodLength)

        let anchor = periodStarts.last ?? profile.lastPeriodStart.map { cal.startOfDay(for: $0) }
        guard let lastStart = anchor else {
            return CyclePrediction(
                cycleDay: 1,
                phase: .unknown,
                cycleLength: cycleLength,
                periodLength: periodLength,
                nextPeriodStart: nil,
                fertileWindow: nil,
                ovulationDay: nil,
                algorithmVersion: Self.algorithmVersion,
                confidenceNote: "Log a period to unlock predictions."
            )
        }

        var daysSince = cal.dateComponents([.day], from: lastStart, to: today).day ?? 0
        if daysSince < 0 { daysSince = 0 }

        // If we've passed expected cycle length without a new period, keep counting.
        let cycleDay = (daysSince % max(cycleLength, 1)) + 1
        let nextPeriod: Date = {
            if daysSince >= cycleLength {
                return cal.date(byAdding: .day, value: cycleLength - (daysSince % cycleLength), to: today) ?? today
            }
            return cal.date(byAdding: .day, value: cycleLength - daysSince, to: today) ?? today
        }()

        let ovulationOffset = max(cycleLength - 14, 1)
        let ovulation = cal.date(byAdding: .day, value: ovulationOffset - 1, to: lastStart)
        let fertileStart = cal.date(byAdding: .day, value: max(ovulationOffset - 5, 0), to: lastStart)
        let fertileEnd = cal.date(byAdding: .day, value: ovulationOffset + 1, to: lastStart)

        var fertile: ClosedRange<Date>?
        if let fertileStart, let fertileEnd, fertileStart <= fertileEnd {
            fertile = fertileStart...fertileEnd
        }

        let phase = phase(
            cycleDay: cycleDay,
            periodLength: periodLength,
            ovulationOffset: ovulationOffset,
            today: today,
            fertile: fertile,
            ovulation: ovulation,
            logs: logs
        )

        let cyclesLogged = max(periodStarts.count, profile.lastPeriodStart == nil ? 0 : 1)
        let confidence: String = {
            if cyclesLogged >= 2 {
                return "Based on your last \(min(cyclesLogged, 6)) cycles (avg \(cycleLength) days)."
            }
            return "Using your typical \(cycleLength)-day cycle until more history is logged. Not contraception."
        }()

        return CyclePrediction(
            cycleDay: cycleDay,
            phase: phase,
            cycleLength: cycleLength,
            periodLength: periodLength,
            nextPeriodStart: nextPeriod,
            fertileWindow: fertile,
            ovulationDay: ovulation,
            algorithmVersion: Self.algorithmVersion,
            confidenceNote: confidence
        )
    }

    func dayMarker(for date: Date, profile: UserProfile, logs: [DayLog]) -> DayMarker {
        let prediction = predict(profile: profile, logs: logs, asOf: date)
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        let loggedPeriod = logs.contains { cal.isDate($0.date, inSameDayAs: day) && $0.flow.isPeriod }

        // Never treat a future day as already-logged period — those are predictions until the day arrives.
        if loggedPeriod {
            return day > today ? .predictedPeriod : .loggedPeriod
        }

        if let periodMarker = expectedPeriodMarker(
            day: day,
            today: today,
            start: currentPeriodStart(profile: profile, logs: logs),
            length: prediction.periodLength
        ) {
            return periodMarker
        }

        if let ov = prediction.ovulationDay, cal.isDate(ov, inSameDayAs: day) {
            return .ovulation
        }
        if let fertile = prediction.fertileWindow, fertile.contains(day) {
            return .fertile
        }
        if let next = prediction.nextPeriodStart,
           let periodMarker = expectedPeriodMarker(
            day: day,
            today: today,
            start: cal.startOfDay(for: next),
            length: prediction.periodLength
           ) {
            return periodMarker
        }
        return .none
    }

    /// Unlogged days inside an expected period window: future/today = predicted, past = overdue.
    private func expectedPeriodMarker(day: Date, today: Date, start: Date?, length: Int) -> DayMarker? {
        guard let start else { return nil }
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: max(length, 1) - 1, to: start) ?? start
        guard day >= start && day <= end else { return nil }
        return day < today ? .overduePeriod : .predictedPeriod
    }

    private func currentPeriodStart(profile: UserProfile, logs: [DayLog]) -> Date? {
        let cal = Calendar.current
        return detectPeriodStarts(from: logs).last
            ?? profile.lastPeriodStart.map { cal.startOfDay(for: $0) }
    }

    enum DayMarker {
        case none, loggedPeriod, predictedPeriod, overduePeriod, fertile, ovulation
    }

    private func detectPeriodStarts(from logs: [DayLog]) -> [Date] {
        let cal = Calendar.current
        let periodDays = logs
            .filter { $0.flow.isPeriod }
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

    private func averageCycleLength(starts: [Date], fallback: Int) -> Int {
        guard starts.count >= 2 else { return max(fallback, 21) }
        let cal = Calendar.current
        let recent = starts.suffix(7)
        var lengths: [Int] = []
        let array = Array(recent)
        for i in 1..<array.count {
            let days = cal.dateComponents([.day], from: array[i - 1], to: array[i]).day ?? 0
            if (21...45).contains(days) {
                lengths.append(days)
            }
        }
        guard !lengths.isEmpty else { return max(fallback, 21) }
        return max(Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded()), 21)
    }

    private func averagePeriodLength(logs: [DayLog], fallback: Int) -> Int {
        let cal = Calendar.current
        let starts = detectPeriodStarts(from: logs)
        guard !starts.isEmpty else { return max(fallback, 2) }
        var lengths: [Int] = []
        for start in starts.suffix(6) {
            var length = 0
            for offset in 0..<10 {
                guard let day = cal.date(byAdding: .day, value: offset, to: start) else { break }
                if logs.contains(where: { cal.isDate($0.date, inSameDayAs: day) && $0.flow.isPeriod }) {
                    length += 1
                } else if offset > 0 {
                    break
                }
            }
            if length > 0 { lengths.append(length) }
        }
        guard !lengths.isEmpty else { return max(fallback, 2) }
        return max(Int((Double(lengths.reduce(0, +)) / Double(lengths.count)).rounded()), 2)
    }

    private func phase(
        cycleDay: Int,
        periodLength: Int,
        ovulationOffset: Int,
        today: Date,
        fertile: ClosedRange<Date>?,
        ovulation: Date?,
        logs: [DayLog]
    ) -> CyclePhase {
        let cal = Calendar.current
        if logs.contains(where: { cal.isDate($0.date, inSameDayAs: today) && $0.flow.isPeriod }) || cycleDay <= periodLength {
            return .menstrual
        }
        if let ovulation, cal.isDate(ovulation, inSameDayAs: today) {
            return .ovulation
        }
        if let fertile, fertile.contains(today) {
            return .fertile
        }
        if cycleDay < ovulationOffset {
            return .follicular
        }
        return .luteal
    }
}
