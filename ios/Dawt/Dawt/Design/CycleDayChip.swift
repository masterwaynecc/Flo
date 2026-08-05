import SwiftUI

/// Visual language shared by the owner calendar, partner calendar, and legend.
enum CycleDayStyle: Equatable {
    case none
    case loggedPeriod      // pink filled
    case predictedPeriod   // pink dotted circle
    case overduePeriod     // gray filled — expected/predicted period day with no log yet
    case fertile           // teal number only
    case ovulation         // teal dotted circle

    init(_ marker: CyclePredictionEngine.DayMarker) {
        switch marker {
        case .none: self = .none
        case .loggedPeriod: self = .loggedPeriod
        case .predictedPeriod: self = .predictedPeriod
        case .overduePeriod: self = .overduePeriod
        case .fertile: self = .fertile
        case .ovulation: self = .ovulation
        }
    }
}

struct CycleDayChip: View {
    let day: Int
    let style: CycleDayStyle
    var size: CGFloat = 40
    var emphasizeToday: Bool = false

    var body: some View {
        ZStack {
            chipBackground
            Text("\(day)")
                .font(DawtType.body(size * 0.38, weight: numberWeight))
                .foregroundStyle(numberColor)
        }
        .frame(width: size, height: size)
        .overlay {
            if emphasizeToday && style == .none {
                Circle()
                    .strokeBorder(DawtColor.rose.opacity(0.45), lineWidth: 1.5)
            }
        }
    }

    @ViewBuilder
    private var chipBackground: some View {
        switch style {
        case .loggedPeriod:
            Circle().fill(DawtColor.period)
        case .predictedPeriod:
            DottedRing(color: DawtColor.period, size: size, dotCount: 16)
        case .overduePeriod:
            Circle().fill(Color(white: 0.82))
        case .ovulation:
            DottedRing(color: DawtColor.fertile, size: size, dotCount: 16)
        case .fertile, .none:
            Color.clear
        }
    }

    private var numberColor: Color {
        switch style {
        case .loggedPeriod: return .white
        case .predictedPeriod: return DawtColor.period
        case .overduePeriod: return DawtColor.ink
        case .fertile, .ovulation: return DawtColor.fertile
        case .none: return DawtColor.ink
        }
    }

    private var numberWeight: Font.Weight {
        switch style {
        case .loggedPeriod, .overduePeriod: return .bold
        case .predictedPeriod, .ovulation, .fertile: return .semibold
        case .none: return emphasizeToday ? .bold : .regular
        }
    }
}

/// Evenly spaced circular beads — avoids dash-pattern overlap where a stroked path closes.
private struct DottedRing: View {
    let color: Color
    let size: CGFloat
    var dotCount: Int = 16

    var body: some View {
        let dot = max(size * 0.095, 2.6)
        let radius = (size - dot) / 2
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            for i in 0..<dotCount {
                let angle = (Double(i) / Double(dotCount)) * 2 * Double.pi - Double.pi / 2
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                let rect = CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

struct CycleDayLegendRow: View {
    let style: CycleDayStyle
    let title: String
    let titleColor: Color
    let detail: String
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            CycleDayChip(day: 26, style: style, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DawtType.body(16, weight: .semibold))
                    .foregroundStyle(titleColor)
                Text(detail)
                    .font(DawtType.body(15))
                    .foregroundStyle(onDark ? Color.white : DawtColor.ink)
            }
        }
    }
}
