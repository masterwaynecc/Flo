import Charts
import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appState: AppState

    private let trendsEngine = TrendsEngine()

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

                        trendsSection

                        NavigationLink {
                            PartnerSharingView()
                                .environmentObject(appState)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Partner sharing")
                                        .font(DawtType.body(16, weight: .semibold))
                                        .foregroundStyle(DawtColor.ink)
                                    Text("Invite someone to see predictions — not your diary.")
                                        .font(DawtType.body(13))
                                        .foregroundStyle(DawtColor.inkMuted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(DawtColor.inkMuted)
                            }
                            .dawtCard()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var report: TrendsReport {
        let titles = Dictionary(
            uniqueKeysWithValues: (SymptomCatalog.symptoms + SymptomCatalog.moods).map { ($0.id, $0.title) }
        )
        return trendsEngine.report(logs: appState.dayLogs, catalogTitles: titles)
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
        return HStack(spacing: 12) {
            stat(title: "Cycle", value: "\(prediction.cycleLength)d")
            stat(title: "Period", value: "\(prediction.periodLength)d")
            stat(title: "Logged", value: "\(report.loggedDays)")
            stat(title: "Period days", value: "\(report.periodDays)")
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(DawtType.body(18, weight: .semibold))

            if report.cycleLengths.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cycle length")
                        .font(DawtType.body(14, weight: .semibold))
                    if let avg = report.averageCycleLength {
                        Text("Average \(avg) days across \(report.cycleLengths.count) cycles")
                            .font(DawtType.body(12))
                            .foregroundStyle(DawtColor.inkMuted)
                    }
                    Chart(report.cycleLengths) { point in
                        LineMark(
                            x: .value("Cycle", point.start),
                            y: .value("Days", point.length)
                        )
                        .foregroundStyle(DawtColor.rose)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Cycle", point.start),
                            y: .value("Days", point.length)
                        )
                        .foregroundStyle(DawtColor.roseDeep)
                    }
                    .frame(height: 160)
                    .chartYScale(domain: 20...45)
                }
                .dawtCard()
            } else {
                Text("Log at least two periods to unlock cycle-length trends.")
                    .font(DawtType.body(13))
                    .foregroundStyle(DawtColor.inkMuted)
                    .dawtCard()
            }

            if !report.flowLast60.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Flow (60 days)")
                        .font(DawtType.body(14, weight: .semibold))
                    Chart(report.flowLast60) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Flow", point.intensity)
                        )
                        .foregroundStyle(DawtColor.period.opacity(0.85))
                    }
                    .frame(height: 120)
                    .chartYScale(domain: 0...4)
                    .chartYAxis {
                        AxisMarks(values: [0, 1, 2, 3, 4]) { value in
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text(flowLabel(v)).font(.caption2)
                                }
                            }
                        }
                    }
                }
                .dawtCard()
            }

            if !report.topSymptoms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most logged symptoms")
                        .font(DawtType.body(14, weight: .semibold))
                    ForEach(report.topSymptoms) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            Text("\(item.count)")
                                .foregroundStyle(DawtColor.inkMuted)
                        }
                        .font(DawtType.body(14))
                    }
                }
                .dawtCard()
            }
        }
    }

    private func flowLabel(_ value: Int) -> String {
        switch value {
        case 1: return "S"
        case 2: return "L"
        case 3: return "M"
        case 4: return "H"
        default: return "—"
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
