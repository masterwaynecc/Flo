import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var month: Date = Date()

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                LumaBackground()
                VStack(spacing: 16) {
                    header
                    weekdayHeader
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(daysInMonth, id: \.self) { date in
                            if let date {
                                dayCell(date)
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    legend
                        .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 8)
            }
            .navigationTitle("Calendar")
        }
    }

    private var header: some View {
        HStack {
            Button {
                month = cal.date(byAdding: .month, value: -1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(LumaType.body(18, weight: .semibold))
            Spacer()
            Button {
                month = cal.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(LumaColor.ink)
        .padding(.horizontal, 20)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                Text(d)
                    .font(LumaType.body(12, weight: .semibold))
                    .foregroundStyle(LumaColor.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }

    private func dayCell(_ date: Date) -> some View {
        let marker = appState.predictionEngine.dayMarker(for: date, profile: appState.profile, logs: appState.dayLogs)
        let isToday = cal.isDateInToday(date)
        return Button {
            appState.openDayLog(for: date)
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: date))")
                    .font(LumaType.body(15, weight: isToday ? .bold : .regular))
                    .foregroundStyle(LumaColor.ink)
                Circle()
                    .fill(markerColor(marker))
                    .frame(width: 7, height: 7)
                    .opacity(marker == .none ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                Circle()
                    .fill(isToday ? LumaColor.rose.opacity(0.15) : Color.clear)
                    .padding(2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility(date: date, marker: marker))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem("Period", LumaColor.period)
            legendItem("Predicted", LumaColor.period.opacity(0.45))
            legendItem("Fertile", LumaColor.fertile)
            legendItem("Ovulation", LumaColor.ovulation)
        }
        .font(LumaType.body(11))
        .foregroundStyle(LumaColor.inkMuted)
        .lumaCard()
    }

    private func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
        }
    }

    private var daysInMonth: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
        let firstWeekday = cal.component(.weekday, from: first) - 1
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            cells.append(cal.date(byAdding: .day, value: day - 1, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func markerColor(_ marker: CyclePredictionEngine.DayMarker) -> Color {
        switch marker {
        case .none: return .clear
        case .loggedPeriod: return LumaColor.period
        case .predictedPeriod: return LumaColor.period.opacity(0.45)
        case .fertile: return LumaColor.fertile
        case .ovulation: return LumaColor.ovulation
        }
    }

    private func accessibility(date: Date, marker: CyclePredictionEngine.DayMarker) -> String {
        let day = date.formatted(date: .abbreviated, time: .omitted)
        switch marker {
        case .none: return day
        case .loggedPeriod: return "\(day), logged period"
        case .predictedPeriod: return "\(day), predicted period"
        case .fertile: return "\(day), fertile window"
        case .ovulation: return "\(day), estimated ovulation"
        }
    }
}
