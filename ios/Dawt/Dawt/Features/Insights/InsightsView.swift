import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                DawtBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Insights")
                            .font(DawtType.display(32, weight: .bold))
                            .foregroundStyle(DawtColor.ink)

                        insightCard(appState.todayInsight)

                        statsCard

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Coming in Phase 2")
                                .font(DawtType.body(16, weight: .semibold))
                            Text("Cycle trends, doctor-shareable PDF reports, and the Symptom Checker will land here.")
                                .font(DawtType.body(14))
                                .foregroundStyle(DawtColor.inkMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .dawtCard()
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func insightCard(_ insight: DailyInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(insight.source == .ai ? "AI insight" : "Daily story", systemImage: "book.pages")
                .font(DawtType.body(12, weight: .semibold))
                .foregroundStyle(DawtColor.fertile)
            Text(insight.title)
                .font(DawtType.body(20, weight: .semibold))
            Text(insight.body)
                .font(DawtType.body(15))
                .foregroundStyle(DawtColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawtCard()
    }

    private var statsCard: some View {
        let prediction = appState.prediction
        let periodDays = appState.dayLogs.filter { $0.flow.isPeriod }.count
        return HStack(spacing: 12) {
            stat(title: "Cycle", value: "\(prediction.cycleLength)d")
            stat(title: "Period", value: "\(prediction.periodLength)d")
            stat(title: "Logged", value: "\(periodDays)")
            stat(title: "Catalog", value: "\(SymptomCatalog.allCount)")
        }
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(DawtType.display(22, weight: .bold))
            Text(title).font(DawtType.body(12)).foregroundStyle(DawtColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .dawtCard()
    }
}
