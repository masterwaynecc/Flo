import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var month: Date = Date()

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                DawtBackground()
                VStack(spacing: 16) {
                    header
                    weekdayHeader
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(daysInMonth, id: \.self) { date in
                            if let date {
                                dayCell(date)
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }
                    .padding(.horizontal, 12)

                    legend
                        .padding(.horizontal, 20)

                    Text("Predictions shown for the next \(CyclePredictionEngine.forecastMonths) months.")
                        .font(DawtType.body(11))
                        .foregroundStyle(DawtColor.inkMuted)
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
                .font(DawtType.body(18, weight: .semibold))
            Spacer()
            Button {
                month = cal.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(DawtColor.ink)
        .padding(.horizontal, 20)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                Text(d)
                    .font(DawtType.body(12, weight: .semibold))
                    .foregroundStyle(DawtColor.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    private func dayCell(_ date: Date) -> some View {
        let marker = appState.predictionEngine.dayMarker(for: date, profile: appState.profile, logs: appState.dayLogs)
        let style = CycleDayStyle(marker)
        let day = cal.component(.day, from: date)
        return Button {
            appState.openDayLog(for: date)
        } label: {
            CycleDayChip(
                day: day,
                style: style,
                size: 40,
                emphasizeToday: cal.isDateInToday(date)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility(date: date, style: style))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legend")
                .font(DawtType.body(13, weight: .semibold))
                .foregroundStyle(DawtColor.inkMuted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                miniLegend(.loggedPeriod, "Logged period")
                miniLegend(.predictedPeriod, "Predicted period")
                miniLegend(.fertile, "Fertile window")
                miniLegend(.ovulation, "Ovulation")
                miniLegend(.overduePeriod, "Expected period, not logged")
            }
        }
        .dawtCard()
    }

    private func miniLegend(_ style: CycleDayStyle, _ title: String) -> some View {
        HStack(spacing: 8) {
            CycleDayChip(day: 26, style: style, size: 28)
            Text(title)
                .font(DawtType.body(12))
                .foregroundStyle(DawtColor.inkMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func accessibility(date: Date, style: CycleDayStyle) -> String {
        let day = date.formatted(date: .abbreviated, time: .omitted)
        switch style {
        case .none: return day
        case .loggedPeriod: return "\(day), logged period"
        case .predictedPeriod: return "\(day), predicted period"
        case .overduePeriod: return "\(day), period not logged"
        case .fertile: return "\(day), fertile window"
        case .ovulation: return "\(day), estimated ovulation"
        }
    }
}
