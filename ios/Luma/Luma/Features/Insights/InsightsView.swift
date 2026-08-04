import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                LumaBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Insights")
                            .font(LumaType.display(32, weight: .bold))
                            .foregroundStyle(LumaColor.ink)

                        insightCard(appState.todayInsight)

                        statsCard

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Coming in Phase 2")
                                .font(LumaType.body(16, weight: .semibold))
                            Text("Cycle trends, doctor-shareable PDF reports, and the Symptom Checker will land here.")
                                .font(LumaType.body(14))
                                .foregroundStyle(LumaColor.inkMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lumaCard()
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
                .font(LumaType.body(12, weight: .semibold))
                .foregroundStyle(LumaColor.fertile)
            Text(insight.title)
                .font(LumaType.body(20, weight: .semibold))
            Text(insight.body)
                .font(LumaType.body(15))
                .foregroundStyle(LumaColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumaCard()
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
            Text(value).font(LumaType.display(22, weight: .bold))
            Text(title).font(LumaType.body(12)).foregroundStyle(LumaColor.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .lumaCard()
    }
}
