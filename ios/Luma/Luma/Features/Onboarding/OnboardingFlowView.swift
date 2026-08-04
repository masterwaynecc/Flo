import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var step = 0
    @State private var draft = OnboardingDraft()

    var body: some View {
        ZStack {
            LumaBackground()
            VStack(spacing: 0) {
                progress
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Group {
                    switch step {
                    case 0: welcome
                    case 1: goal
                    case 2: lastPeriod
                    case 3: lengths
                    case 4: disclaimer
                    default: welcome
                    }
                }
                .padding(24)
                .animation(.easeInOut(duration: 0.25), value: step)

                Spacer()

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .foregroundStyle(LumaColor.inkMuted)
                    }
                    Spacer()
                    Button(step == 4 ? "Start tracking" : "Continue") {
                        advance()
                    }
                    .buttonStyle(LumaPrimaryButtonStyle())
                    .disabled(step == 4 && !draft.acceptedDisclaimer)
                }
                .padding(24)
            }
        }
    }

    private var progress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.5))
                Capsule()
                    .fill(LumaColor.rose)
                    .frame(width: geo.size.width * CGFloat(step + 1) / 5)
            }
        }
        .frame(height: 6)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Luma")
                .font(LumaType.display(48))
                .foregroundStyle(LumaColor.roseDeep)
            Text("Cycle clarity, privately yours.")
                .font(LumaType.display(28, weight: .semibold))
                .foregroundStyle(LumaColor.ink)
            Text("Free and open source. Track periods, symptoms, and ask a model-agnostic Health Assistant. Not medical advice or contraception.")
                .font(LumaType.body())
                .foregroundStyle(LumaColor.inkMuted)
            Toggle("I'm under 18 — use teen-friendly mode", isOn: $draft.teenMode)
                .tint(LumaColor.rose)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What brings you here?")
                .font(LumaType.display(28, weight: .semibold))
            ForEach(LifeStageGoal.allCases) { item in
                Button {
                    draft.goal = item
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(LumaType.body(17, weight: .semibold))
                            Text(item.subtitle).font(LumaType.body(14)).foregroundStyle(LumaColor.inkMuted)
                        }
                        Spacer()
                        if draft.goal == item {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(LumaColor.rose)
                        }
                    }
                    .lumaCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var lastPeriod: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When did your last period start?")
                .font(LumaType.display(28, weight: .semibold))
            DatePicker("Last period start", selection: $draft.lastPeriodStart, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(LumaColor.rose)
                .lumaCard()
        }
    }

    private var lengths: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your typical cycle")
                .font(LumaType.display(28, weight: .semibold))
            stepperCard(title: "Cycle length", value: $draft.cycleLength, range: 21...45, unit: "days")
            stepperCard(title: "Period length", value: $draft.periodLength, range: 2...10, unit: "days")
            Text("You can change these anytime. Defaults work if you're unsure.")
                .font(LumaType.body(14))
                .foregroundStyle(LumaColor.inkMuted)
        }
    }

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Before we continue")
                .font(LumaType.display(28, weight: .semibold))
            Text("Luma provides educational information only. It does not diagnose, treat, or prevent pregnancy. Predictions can be wrong—especially with irregular cycles. Talk to a qualified clinician about your health.")
                .font(LumaType.body())
                .foregroundStyle(LumaColor.inkMuted)
                .lumaCard()
            Toggle("I understand and want to continue", isOn: $draft.acceptedDisclaimer)
                .tint(LumaColor.rose)
        }
    }

    private func stepperCard(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(LumaType.body(15, weight: .medium))
            HStack {
                Text("\(value.wrappedValue) \(unit)")
                    .font(LumaType.display(32, weight: .bold))
                Spacer()
                Stepper("", value: value, in: range).labelsHidden()
            }
        }
        .lumaCard()
    }

    private func advance() {
        if step < 4 {
            step += 1
        } else if draft.acceptedDisclaimer {
            appState.completeOnboarding(draft)
        }
    }
}

struct LumaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LumaType.body(16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(LumaColor.rose.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
    }
}
