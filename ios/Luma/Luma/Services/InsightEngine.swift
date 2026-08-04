import Foundation

struct InsightEngine {
    func insight(for prediction: CyclePrediction, profile: UserProfile, logs: [DayLog]) -> DailyInsight {
        let recentSymptoms = logs
            .sorted { $0.date > $1.date }
            .prefix(3)
            .flatMap(\.symptomIDs)

        switch prediction.phase {
        case .menstrual:
            return DailyInsight(
                id: "menstrual",
                title: "Period days",
                body: recentSymptoms.contains("cramps")
                    ? "Cramps logged recently — gentle movement and heat can help some people. Educational only."
                    : "You're in your period phase. Log flow daily so predictions stay sharp.",
                source: .template
            )
        case .follicular:
            return DailyInsight(
                id: "follicular",
                title: "Energy may rise",
                body: "Follicular phase often brings steadier energy. Track mood to spot your personal pattern.",
                source: .template
            )
        case .fertile:
            return DailyInsight(
                id: "fertile",
                title: "Fertile window",
                body: profile.goal == .ttc
                    ? "You're in an estimated fertile window. Luma is not contraception or medical advice."
                    : "Estimated fertile window based on your cycle history. Not a birth control method.",
                source: .template
            )
        case .ovulation:
            return DailyInsight(
                id: "ovulation",
                title: "Estimated ovulation",
                body: "Today aligns with your estimated ovulation day. Confirm patterns with logs over time.",
                source: .template
            )
        case .luteal:
            return DailyInsight(
                id: "luteal",
                title: "Luteal phase",
                body: nextPeriodCopy(prediction),
                source: .template
            )
        case .unknown:
            return DailyInsight(
                id: "unknown",
                title: "Welcome to Luma",
                body: "Log your period and a few symptoms — predictions get better after two cycles.",
                source: .template
            )
        }
    }

    private func nextPeriodCopy(_ prediction: CyclePrediction) -> String {
        guard let next = prediction.nextPeriodStart else {
            return "Log more cycles to estimate your next period."
        }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: next).day ?? 0
        if days <= 0 {
            return "Your period may be due around now. Log when it starts."
        }
        return "Next period estimated in \(days) day\(days == 1 ? "" : "s"). \(prediction.confidenceNote)"
    }
}
