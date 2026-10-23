import Charts
import Foundation
import SwiftUI

struct ClientActivityDashboardView: View {
    let snapshot: ClientSnapshot
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "it_IT")
        value.firstWeekday = 2
        return value
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth)!
    }

    private var monthDates: [Date] {
        let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start)?.start ?? monthInterval.start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek) }
    }

    private var allItems: [ClientActivityItem] {
        ClientActivityInsights.items(state: session.activity, snapshot: snapshot)
    }

    private var selectedItems: [ClientActivityItem] {
        allItems.filter { calendar.isDate($0.completedAt, inSameDayAs: selectedDate) }
    }

    private var monthSummary: ClientActivitySummary {
        ClientActivityInsights.summary(state: session.activity, snapshot: snapshot, interval: monthInterval, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Attività").font(ClientTypography.section).foregroundStyle(ClientClay.color(.textPrimary))
            calendarCard
            selectedDayCard
            monthSummaryView
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mese precedente")
                Spacer()
                VStack(spacing: 2) {
                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()).capitalized)
                        .font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                    if !calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                        Button("Oggi") { displayedMonth = Date(); selectedDate = Date() }
                            .font(.subheadline.weight(.bold)).foregroundStyle(ClientClay.color(.brandAccent))
                            .frame(minHeight: ClientControlSize.minimumTarget)
                    }
                }
                Spacer()
                Button { moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mese successivo")
            }

            if dynamicTypeSize.isAccessibilitySize {
                accessibleDayPicker
            } else {
                ViewThatFits(in: .horizontal) {
                    calendarGrid.frame(minWidth: 7 * ClientControlSize.minimumTarget)
                    accessibleDayPicker
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: ClientSpacing.control) { calendarLegend }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: ClientSpacing.related) { calendarLegend }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: ClientSpacing.micro) {
            ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, day in
                Text(day).font(.caption.weight(.bold)).foregroundStyle(ClientClay.color(.textSecondary))
                    .accessibilityHidden(true)
            }
            ForEach(monthDates, id: \.self) { date in dayCell(date) }
        }
    }

    private var accessibleDayPicker: some View {
        VStack(alignment: .leading, spacing: ClientSpacing.related) {
            DatePicker("Giorno da consultare", selection: $selectedDate,
                       in: monthInterval.start...monthInterval.end.addingTimeInterval(-1),
                       displayedComponents: .date)
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "it_IT"))
                .environment(\.calendar, calendar)
            Text("Scegli un giorno: le attività sono elencate qui sotto.")
                .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
        }
    }

    @ViewBuilder private var calendarLegend: some View {
        legendItem("Palestra", symbol: "dumbbell.fill", tint: ClientClay.color(.workoutAccent))
        legendItem("Corsa", symbol: "figure.run", tint: ClientClay.color(.runningAccent))
        legendItem("Entrambi", symbol: "square.stack.fill", tint: ClientClay.color(.success))
    }

    private func dayCell(_ date: Date) -> some View {
        let isInMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let items = allItems.filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
        let hasGym = items.contains { $0.kind == .gym }
        let hasRun = items.contains { $0.kind == .running }
        let hasActivity = hasGym || hasRun

        return Button {
            guard isInMonth else { return }
            selectedDate = date
            ClientHaptics.selection()
        } label: {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.day()))
                    .font(.caption.weight(isSelected || isToday ? .bold : .medium))
                    .underline(isToday, color: ClientClay.color(.brandAccent))
                    .foregroundStyle(ClientClay.color(isInMonth ? .textPrimary : .textDisabled))
                if hasActivity {
                    Image(systemName: hasGym && hasRun ? "square.stack.fill" : hasGym ? "dumbbell.fill" : "figure.run")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ClientClay.color(hasGym && hasRun ? .success : hasGym ? .workoutAccent : .runningAccent))
                } else {
                    // Reserves marker space without a false activity icon.
                    Text(" ").font(.caption2).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(dayCellBackground(hasGym: hasGym, hasRun: hasRun, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? ClientClay.color(.textEmphasis) : .clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInMonth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: date, items: items, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isInMonth ? "Mostra il dettaglio del giorno" : "")
    }

    private func dayCellBackground(hasGym: Bool, hasRun: Bool, isSelected: Bool) -> AnyShapeStyle {
        if hasGym || hasRun { return AnyShapeStyle(ClientClay.color(.surfaceInteractive)) }
        if isSelected { return AnyShapeStyle(ClientClay.color(.surfaceElevated)) }
        return AnyShapeStyle(Color.clear)
    }

    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
            if selectedItems.isEmpty {
                Label("Nessuna attività registrata", systemImage: "calendar.badge.minus")
                    .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary)).padding(.vertical, 6)
            } else {
                ForEach(selectedItems) { item in
                    activityRow(item)
                    if item.id != selectedItems.last?.id { Divider().overlay(ClientClay.color(.borderSubtle)) }
                }
            }
        }
        .padding(.vertical, ClientSpacing.related)
    }

    private func activityRow(_ item: ClientActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind == .gym ? "dumbbell.fill" : "figure.run")
                .foregroundStyle(item.kind == .gym ? ClientClay.color(.workoutAccent) : ClientClay.color(.runningAccent))
                .frame(width: 34, height: 34)
                .background((item.kind == .gym ? ClientClay.color(.workoutAccent) : ClientClay.color(.runningAccent)).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.kind == .gym ? "PALESTRA" : "CORSA").font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(ClientClay.color(.textSecondary))
                Text(item.title).font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
                HStack(spacing: 10) {
                    Label(ClientActivityFormat.duration(item.durationSeconds), systemImage: "timer")
                    if let distance = item.distanceKm {
                        Label("\(distance.formatted(.number.precision(.fractionLength(2)))) km", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                }
                .font(.caption).foregroundStyle(ClientClay.color(.textSecondary))
                if let pace = item.averagePaceMinutesPerKm, let speed = item.averageSpeedKmh {
                    Text("\(ClientActivityFormat.pace(pace)) · \(speed.formatted(.number.precision(.fractionLength(1)))) km/h")
                        .font(.caption.monospacedDigit()).foregroundStyle(ClientClay.color(.textSecondary))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var monthSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Riepilogo del mese · \(displayedMonth.formatted(.dateTime.month(.wide)).capitalized)", systemImage: "calendar")
                .font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryTile("Palestra", value: "\(monthSummary.gymSessions)", symbol: "dumbbell.fill", tint: ClientClay.color(.workoutAccent))
                summaryTile("Corse", value: "\(monthSummary.runs)", symbol: "figure.run", tint: ClientClay.color(.runningAccent))
                summaryTile("Km corsi", value: monthSummary.runningDistanceKm > 0 ? monthSummary.runningDistanceKm.formatted(.number.precision(.fractionLength(1))) : "—", symbol: "road.lanes", tint: ClientClay.color(.runningAccent))
                summaryTile("Giorni attivi", value: "\(monthSummary.activeDays)", symbol: "calendar.badge.checkmark", tint: ClientClay.color(.success))
                summaryTile("PB ottenuti", value: "\(monthSummary.personalBests)", symbol: "trophy.fill", tint: ClientClay.color(.warning))
            }
        }
    }

    private func summaryTile(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(tint)
            Text(value).font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit()).foregroundStyle(ClientClay.color(.textPrimary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ text: String, symbol: String, tint: Color) -> some View {
        Label { Text(text).foregroundStyle(ClientClay.color(.textSecondary)) }
            icon: { Image(systemName: symbol).foregroundStyle(tint) }
            .font(.caption.weight(.semibold))
    }

    private func moveMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDate = calendar.dateInterval(of: .month, for: next)?.start ?? next
        ClientHaptics.selection()
    }

    private func accessibilityLabel(for date: Date, items: [ClientActivityItem], isToday: Bool) -> String {
        let gym = items.filter { $0.kind == .gym }.count
        let runs = items.filter { $0.kind == .running }.count
        let status = items.isEmpty ? "nessuna attività" : "\(gym) palestra, \(runs) corsa"
        return "\(date.formatted(date: .long, time: .omitted))\(isToday ? ", oggi" : ""), \(status)"
    }
}

struct ClientActivityRecapView: View {
    let snapshot: ClientSnapshot
    @EnvironmentObject private var session: ClientSessionStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: ClientActivityPeriod = .month

    private var interval: DateInterval { ClientActivityInsights.interval(for: period) }
    private var summary: ClientActivitySummary {
        ClientActivityInsights.summary(state: session.activity, snapshot: snapshot, interval: interval)
    }
    private var buckets: [ClientActivityTrendBucket] {
        ClientActivityInsights.trendBuckets(state: session.activity, snapshot: snapshot, period: period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactHeader
            ClientActivityRecapHeader(activeDays: summary.activeDays, duration: ClientActivityFormat.compactDuration(summary.activeSeconds))
            periodSelector
            metricGrid
            if summary.runningDistanceKm > 0 { distanceScaleIndicator }
            if buckets.isEmpty {
                recapStatus("Nessuna attività nel periodo. Le sessioni completate appariranno qui.", symbol: "chart.bar.xaxis")
            } else {
                if buckets.contains(where: { $0.runningKm > 0 }) {
                    distanceChart
                } else {
                    recapStatus("Nessuna distanza GPS registrata in questo periodo.", symbol: "location.slash")
                }
            }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: ClientSpacing.micro) {
            Text("Riepilogo").font(ClientTypography.section).foregroundStyle(ClientClay.color(.textPrimary))
            Text(period == .month ? "Questo mese" : period == .year ? "Ultimo anno" : "Ultimi \(period.rawValue) mesi")
                .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .accessibilityElement(children: .combine)
    }

    private var periodSelector: some View {
        ClientCompactSelector(values: ClientActivityPeriod.allCases, selection: $period,
                              title: { $0.title }, accessibilityTitle: "Periodo del riepilogo")
    }

    private func recapStatus(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, ClientSpacing.related)
    }

    private var metricGrid: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            compactMetric("Palestra", value: "\(summary.gymSessions)", symbol: "dumbbell.fill", tint: ClientClay.color(.workoutAccent))
            compactMetric("Corsa", value: "\(summary.runs)", symbol: "figure.run", tint: ClientClay.color(.runningAccent))
            compactMetric("Distanza", value: summary.runningDistanceKm > 0 ? "\(summary.runningDistanceKm.formatted(.number.precision(.fractionLength(1)))) km" : "—", symbol: "road.lanes", tint: ClientClay.color(.runningAccent))
            compactMetric("Personal Best", value: "\(summary.personalBests)", symbol: "trophy.fill", tint: ClientClay.color(.warning))
        }
    }

    private func compactMetric(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold)).foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline.monospacedDigit().weight(.bold)).foregroundStyle(ClientClay.color(.textPrimary))
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(ClientClay.color(.textSecondary))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, ClientSpacing.related)
        .accessibilityElement(children: .combine)
    }

    private var distanceScaleIndicator: some View {
        let maximum = max(5, ceil(summary.runningDistanceKm / 5) * 5)
        let ratio = min(1, max(0, summary.runningDistanceKm / maximum))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Distanza nel periodo", systemImage: "road.lanes")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(ClientClay.color(.textPrimary))
                Spacer()
                Text("\(summary.runningDistanceKm.formatted(.number.precision(.fractionLength(1)))) km")
                    .font(.headline.monospacedDigit()).foregroundStyle(ClientClay.color(.runningAccent))
            }
            GeometryReader { proxy in
                let markerX = max(CGFloat(7), min(proxy.size.width - 7, proxy.size.width * CGFloat(ratio)))
                ZStack(alignment: .leading) {
                    Capsule().fill(ClientClay.color(.surfaceSecondary)).frame(height: 8)
                    Capsule().fill(ClientClay.color(.runningAccent).opacity(0.55)).frame(width: markerX, height: 8)
                    Circle().fill(ClientClay.color(.runningAccent)).frame(width: 14, height: 14)
                        .overlay { Circle().stroke(ClientClay.color(.textPrimary), lineWidth: 2) }
                        .offset(x: markerX - 7)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
            HStack {
                Text("0 km")
                Spacer()
                Text("\(maximum.formatted(.number.precision(.fractionLength(0)))) km")
            }
            .font(.caption2.monospacedDigit()).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Indicatore distanza percorsa")
        .accessibilityValue("\(summary.runningDistanceKm.formatted(.number.precision(.fractionLength(1)))) chilometri su una scala di \(maximum.formatted(.number.precision(.fractionLength(0))))")
    }

    private var distanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chilometri corsi · km per periodo", systemImage: "chart.xyaxis.line")
                .font(.headline).foregroundStyle(ClientClay.color(.textPrimary))
            Chart(buckets) { bucket in
                AreaMark(
                    x: .value("Periodo", bucket.label),
                    y: .value("Chilometri", bucket.runningKm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [ClientClay.color(.runningAccent).opacity(0.30), ClientClay.color(.runningAccent).opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(
                    x: .value("Periodo", bucket.label),
                    y: .value("Chilometri", bucket.runningKm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(ClientClay.color(.runningAccent))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Periodo", bucket.label),
                    y: .value("Chilometri", bucket.runningKm)
                )
                .foregroundStyle(ClientClay.color(.runningAccent))
            }
            .frame(height: 150)
            .chartYAxisLabel("km")
            .chartPlotStyle { $0.background(ClientClay.color(.surfaceSecondary).opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12)) }
        }
        .clayCard(padding: ClientSpacing.control, appearance: .adaptive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grafico dei chilometri corsi nel periodo selezionato")
    }
}

/// The same header used by Riepilogo, isolated for native layout regression tests.
/// Inline summary, not another hero. The vertical candidate wraps at large type.
struct ClientActivityRecapHeader: View {
    let activeDays: Int
    let duration: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: ClientSpacing.section) { metrics }
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: ClientSpacing.related) { metrics }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, ClientSpacing.micro)
    }

    @ViewBuilder private var metrics: some View {
        metric(title: "giorni attivi", value: "\(activeDays)")
        metric(title: "tempo totale", value: duration)
    }

    private func metric(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: ClientSpacing.micro) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(ClientClay.color(.textPrimary))
            Text(title).font(.subheadline).foregroundStyle(ClientClay.color(.textSecondary))
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

private enum ClientActivityFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value >= 3_600 { return String(format: "%dh %02dm", value / 3_600, value / 60 % 60) }
        return String(format: "%d min", max(1, value / 60))
    }

    static func compactDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value == 0 { return "—" }
        if value >= 3_600 { return String(format: "%dh %02dm", value / 3_600, value / 60 % 60) }
        return "\(max(1, value / 60))m"
    }

    static func pace(_ minutesPerKm: Double) -> String {
        let totalSeconds = max(0, Int((minutesPerKm * 60).rounded()))
        return String(format: "%d'%02d\" /km", totalSeconds / 60, totalSeconds % 60)
    }
}
