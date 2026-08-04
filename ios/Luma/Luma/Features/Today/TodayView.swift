import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    private var prediction: CyclePrediction { appState.prediction }
    private var insight: DailyInsight { appState.todayInsight }

    var body: some View {
        NavigationStack {
            ZStack {
                LumaBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        CycleRingView(prediction: prediction)
                            .padding(.top, 8)

                        VStack(spacing: 6) {
                            Text(prediction.phase.title.uppercased())
                                .font(LumaType.body(12, weight: .semibold))
                                .foregroundStyle(LumaColor.roseDeep)
                                .tracking(1.2)
                            Text(predictionCopy)
                                .font(LumaType.body(15))
                                .foregroundStyle(LumaColor.inkMuted)
                                .multilineTextAlignment(.center)
                            Text(prediction.confidenceNote)
                                .font(LumaType.body(12))
                                .foregroundStyle(LumaColor.inkMuted.opacity(0.85))
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
            .navigationTitle("Luma")
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
                .font(LumaType.body(13, weight: .semibold))
                .foregroundStyle(LumaColor.fertile)
            Text(insight.title)
                .font(LumaType.body(18, weight: .semibold))
            Text(insight.body)
                .font(LumaType.body(15))
                .foregroundStyle(LumaColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumaCard()
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                appState.openDayLog()
            } label: {
                Label("Log today", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LumaPrimaryButtonStyle())

            Button {
                appState.showingAssistant = true
            } label: {
                Label("Ask AI", systemImage: "text.bubble")
                    .font(LumaType.body(16, weight: .semibold))
                    .foregroundStyle(LumaColor.roseDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.7), in: Capsule())
            }
        }
    }

    private var disclaimer: some View {
        Text("Educational only · Not contraception · Not medical advice")
            .font(LumaType.body(11))
            .foregroundStyle(LumaColor.inkMuted)
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
                        colors: [LumaColor.rose, LumaColor.fertile, LumaColor.ovulation, LumaColor.roseDeep],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("Day")
                    .font(LumaType.body(14, weight: .medium))
                    .foregroundStyle(LumaColor.inkMuted)
                Text("\(prediction.cycleDay)")
                    .font(LumaType.display(64, weight: .bold))
                    .foregroundStyle(LumaColor.ink)
                    .contentTransition(.numericText())
                Text("of \(prediction.cycleLength)")
                    .font(LumaType.body(14))
                    .foregroundStyle(LumaColor.inkMuted)
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
