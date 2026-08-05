import SwiftUI

enum PartnerCalendarMarkers {
    static func style(for date: Date, snapshot: CycleShareSnapshotDTO) -> CycleDayStyle {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let key = dayKey(day)
        let logged = Set(snapshot.loggedPeriodDates ?? [])
        let today = cal.startOfDay(for: Date())
        let periodLength = max(snapshot.periodLength ?? 5, 1)

        if logged.contains(key) {
            // Future “logged” rows are treated as predictions until that day arrives.
            return day > today ? .predictedPeriod : .loggedPeriod
        }

        if let start = parseDay(snapshot.periodStart) {
            let end = parseDay(snapshot.periodEnd)
                ?? cal.date(byAdding: .day, value: periodLength - 1, to: start)
            if let end, day >= start, day <= end {
                return day < today ? .overduePeriod : .predictedPeriod
            }
        }

        if let ovulation = parseDay(snapshot.ovulationDay), cal.isDate(ovulation, inSameDayAs: day) {
            return .ovulation
        }

        if let start = parseDay(snapshot.fertileWindowStart),
           let end = parseDay(snapshot.fertileWindowEnd),
           day >= cal.startOfDay(for: start),
           day <= cal.startOfDay(for: end) {
            return .fertile
        }

        if let next = parseDay(snapshot.nextPeriodStart) {
            let nextStart = cal.startOfDay(for: next)
            if let predictedEnd = cal.date(byAdding: .day, value: periodLength - 1, to: nextStart),
               day >= nextStart,
               day <= predictedEnd {
                return day < today ? .overduePeriod : .predictedPeriod
            }
        }

        return .none
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.startOfDay(for: date))
    }

    static func parseDay(_ string: String?) -> Date? {
        guard let string else { return nil }
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var comps = DateComponents()
        comps.year = parts[0]
        comps.month = parts[1]
        comps.day = parts[2]
        return Calendar.current.date(from: comps).map { Calendar.current.startOfDay(for: $0) }
    }
}

struct PartnerCalendarView: View {
    let snapshot: CycleShareSnapshotDTO
    @State private var month = Date()
    @State private var showHowItWorks = true

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ZStack {
            DawtBackground()
            VStack(spacing: 16) {
                summaryHeader
                monthHeader
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

                Button {
                    showHowItWorks = true
                } label: {
                    Label("How does it work?", systemImage: "questionmark.circle")
                        .font(DawtType.body(14, weight: .semibold))
                }
                .padding(.top, 4)

                Text("Predictions are educational only — not contraception or medical advice.")
                    .font(DawtType.body(11))
                    .foregroundStyle(DawtColor.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
        }
        .navigationTitle("\(possessive) calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showHowItWorks) {
            PartnerHowItWorksView(possessive: possessive)
        }
    }

    private var possessive: String {
        let label = snapshot.ownerLabel
        if label == "Their" { return "Their" }
        return label.hasSuffix("s") ? "\(label)’" : "\(label)’s"
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let phase = snapshot.phase.flatMap(CyclePhase.init(rawValue:)) {
                Text(phase.title)
                    .font(DawtType.body(20, weight: .semibold))
            }
            if let day = snapshot.cycleDay {
                Text("Cycle day \(day)")
                    .font(DawtType.body(14))
                    .foregroundStyle(DawtColor.inkMuted)
            }
            if let next = snapshot.nextPeriodStart {
                Text("Next period ~ \(next)")
                    .font(DawtType.body(13))
                    .foregroundStyle(DawtColor.roseDeep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var monthHeader: some View {
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
        let style = PartnerCalendarMarkers.style(for: date, snapshot: snapshot)
        let day = cal.component(.day, from: date)
        return CycleDayChip(
            day: day,
            style: style,
            size: 40,
            emphasizeToday: cal.isDateInToday(date)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .accessibilityLabel(accessibility(day: day, style: style))
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

    private func accessibility(day: Int, style: CycleDayStyle) -> String {
        switch style {
        case .none: return "\(day)"
        case .loggedPeriod: return "\(day), logged period"
        case .predictedPeriod: return "\(day), predicted period"
        case .overduePeriod: return "\(day), period not logged"
        case .fertile: return "\(day), fertile window"
        case .ovulation: return "\(day), estimated ovulation"
        }
    }
}

struct PartnerHowItWorksView: View {
    let possessive: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.14, blue: 0.28),
                        Color(red: 0.08, green: 0.18, blue: 0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("How does it work?")
                            .font(DawtType.display(34, weight: .bold))
                            .foregroundStyle(Color(red: 0.72, green: 0.86, blue: 0.95))

                        Text("Open their shared calendar to see period timing and fertile-window estimates.")
                            .font(DawtType.body(16))
                            .foregroundStyle(.white.opacity(0.85))

                        VStack(alignment: .leading, spacing: 22) {
                            CycleDayLegendRow(
                                style: .predictedPeriod,
                                title: "Pink dotted-circle days",
                                titleColor: DawtColor.period,
                                detail: "\(possessive) predicted period days",
                                onDark: true
                            )
                            CycleDayLegendRow(
                                style: .loggedPeriod,
                                title: "Pink filled days",
                                titleColor: DawtColor.period,
                                detail: "\(possessive) logged period days",
                                onDark: true
                            )
                            CycleDayLegendRow(
                                style: .fertile,
                                title: "Teal days",
                                titleColor: DawtColor.fertile,
                                detail: "\(possessive) predicted fertile window",
                                onDark: true
                            )
                            CycleDayLegendRow(
                                style: .ovulation,
                                title: "Teal dotted-circle days",
                                titleColor: DawtColor.fertile,
                                detail: "\(possessive) predicted ovulation days",
                                onDark: true
                            )
                            CycleDayLegendRow(
                                style: .overduePeriod,
                                title: "Gray filled days",
                                titleColor: Color(white: 0.75),
                                detail: "\(possessive) expected period days that haven’t been logged yet",
                                onDark: true
                            )
                        }

                        Text("Remember: dawt’s predictions should not be used as a method of birth control.")
                            .font(DawtType.body(12))
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.top, 8)

                        Button {
                            dismiss()
                        } label: {
                            Text("Go to calendar")
                                .font(DawtType.body(17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.white, in: Capsule())
                                .foregroundStyle(DawtColor.ink)
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
