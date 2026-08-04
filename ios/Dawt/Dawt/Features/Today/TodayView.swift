import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    private var prediction: CyclePrediction { appState.prediction }
    private var insight: DailyInsight { appState.todayInsight }

    var body: some View {
        NavigationStack {
            ZStack {
                DawtBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        CycleRingView(prediction: prediction)
                            .padding(.top, 8)

                        VStack(spacing: 6) {
                            Text(prediction.phase.title.uppercased())
                                .font(DawtType.body(12, weight: .semibold))
                                .foregroundStyle(DawtColor.roseDeep)
                                .tracking(1.2)
                            Text(predictionCopy)
                                .font(DawtType.body(15))
                                .foregroundStyle(DawtColor.inkMuted)
                                .multilineTextAlignment(.center)
                            Text(prediction.confidenceNote)
                                .font(DawtType.body(12))
                                .foregroundStyle(DawtColor.inkMuted.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)

                        insightCard
                        actionRow
                        disclaimer
                    }
                    .padding(20)
                }
            }
            .navigationTitle("dawt")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.showingAssistant = true
                    } label: {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    }
                    .accessibilityLabel("Open Health Assistant")
                }
            }
        }
    }

    private var predictionCopy: String {
        if let next = prediction.nextPeriodStart {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: next).day ?? 0
            if prediction.phase == .menstrual {
                return "Period day \(prediction.cycleDay) of an estimated \(prediction.cycleLength)-day cycle"
            }
            if days <= 0 {
                return "Period may be due — log when it starts"
            }
            return "Next period in about \(days) days · Cycle day \(prediction.cycleDay)"
        }
        return "Log your period to see predictions"
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Today's insight", systemImage: "sparkles")
                .font(DawtType.body(13, weight: .semibold))
                .foregroundStyle(DawtColor.fertile)
            Text(insight.title)
                .font(DawtType.body(18, weight: .semibold))
            Text(insight.body)
                .font(DawtType.body(15))
                .foregroundStyle(DawtColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawtCard()
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                appState.openDayLog()
            } label: {
                Label("Log today", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DawtPrimaryButtonStyle())

            Button {
                appState.showingAssistant = true
            } label: {
                Label("Ask AI", systemImage: "text.bubble")
                    .font(DawtType.body(16, weight: .semibold))
                    .foregroundStyle(DawtColor.roseDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.7), in: Capsule())
            }
        }
    }

    private var disclaimer: some View {
        Text("Educational only · Not contraception · Not medical advice")
            .font(DawtType.body(11))
            .foregroundStyle(DawtColor.inkMuted)
            .frame(maxWidth: .infinity)
    }
}

struct CycleRingView: View {
    let prediction: CyclePrediction
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.55), lineWidth: 18)
            Circle()
                .trim(from: 0, to: appeared ? progress : 0)
                .stroke(
                    AngularGradient(
                        colors: [DawtColor.rose, DawtColor.fertile, DawtColor.ovulation, DawtColor.roseDeep],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("Day")
                    .font(DawtType.body(14, weight: .medium))
                    .foregroundStyle(DawtColor.inkMuted)
                Text("\(prediction.cycleDay)")
                    .font(DawtType.display(64, weight: .bold))
                    .foregroundStyle(DawtColor.ink)
                    .contentTransition(.numericText())
                Text("of \(prediction.cycleLength)")
                    .font(DawtType.body(14))
                    .foregroundStyle(DawtColor.inkMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cycle day \(prediction.cycleDay) of \(prediction.cycleLength), \(prediction.phase.title)")
        }
        .frame(width: 240, height: 240)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { appeared = true }
        }
    }

    private var progress: CGFloat {
        CGFloat(prediction.cycleDay) / CGFloat(max(prediction.cycleLength, 1))
    }
}
