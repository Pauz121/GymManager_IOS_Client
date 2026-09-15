import Charts
import SwiftUI

struct ClientActivityDashboardView: View {
    let snapshot: ClientSnapshot
    @EnvironmentObject private var session: ClientSessionStore
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
        VStack(alignment: .leading, spacing: 18) {
            ClientPageTitle("Attività", eyebrow: "Tutto il movimento", subtitle: "Palestra e corsa, riunite senza duplicare le sessioni.")
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
                        .font(.headline).foregroundStyle(ClientClay.ink)
                    if !calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) {
                        Button("Oggi") { displayedMonth = Date(); selectedDate = Date() }
                            .font(.caption.weight(.bold)).foregroundStyle(ClientClay.accent)
                    }
                }
                Spacer()
                Button { moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mese successivo")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(Array(["L", "M", "M", "G", "V", "S", "D"].enumerated()), id: \.offset) { _, day in
                    Text(day).font(.caption2.weight(.bold)).foregroundStyle(ClientClay.secondaryInk).frame(height: 20)
                }
                ForEach(monthDates, id: \.self) { date in
                    dayCell(date)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            HStack(spacing: 14) {
                legendItem("Palestra", symbol: "dumbbell.fill", tint: ClientClay.accent)
                legendItem("Corsa", symbol: "figure.run", tint: ClientClay.runAccent)
                legendItem("Entrambi", symbol: "square.stack.fill", tint: ClientClay.sage)
            }
            .frame(maxWidth: .infinity)
        }
        .clayCard(padding: 14)
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
                    .foregroundStyle(hasActivity ? Color.white : isInMonth ? ClientClay.ink : ClientClay.tertiaryInk)
                HStack(spacing: 2) {
                    if hasGym { Image(systemName: "dumbbell.fill") }
                    if hasRun { Image(systemName: "figure.run") }
                }
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(hasActivity ? Color.white : ClientClay.secondaryInk)
                .frame(height: 10)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(dayCellBackground(hasGym: hasGym, hasRun: hasRun, isSelected: isSelected), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.9) : isToday ? ClientClay.accentSoft : .clear, lineWidth: isSelected ? 2 : 1.5)
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
        if hasGym && hasRun {
            return AnyShapeStyle(LinearGradient(colors: [ClientClay.accent, ClientClay.runAccent], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if hasGym { return AnyShapeStyle(ClientClay.accent.opacity(0.82)) }
        if hasRun { return AnyShapeStyle(ClientClay.runAccent.opacity(0.82)) }
        if isSelected { return AnyShapeStyle(ClientClay.surfaceElevated) }
        return AnyShapeStyle(Color.clear)
    }

    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.caption.weight(.bold)).tracking(1).foregroundStyle(ClientClay.secondaryInk)
            if selectedItems.isEmpty {
                Label("Nessuna attività registrata", systemImage: "calendar.badge.minus")
                    .font(.subheadline).foregroundStyle(ClientClay.secondaryInk).padding(.vertical, 6)
            } else {
                ForEach(selectedItems) { item in
                    activityRow(item)
                    if item.id != selectedItems.last?.id { Divider().overlay(ClientClay.border) }
                }
            }
        }
        .clayCard()
    }

    private func activityRow(_ item: ClientActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind == .gym ? "dumbbell.fill" : "figure.run")
                .foregroundStyle(item.kind == .gym ? ClientClay.accent : ClientClay.runAccent)
                .frame(width: 34, height: 34)
                .background((item.kind == .gym ? ClientClay.accent : ClientClay.runAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.kind == .gym ? "PALESTRA" : "CORSA").font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(ClientClay.secondaryInk)
                Text(item.title).font(.headline).foregroundStyle(ClientClay.ink)
                HStack(spacing: 10) {
                    Label(ClientActivityFormat.duration(item.durationSeconds), systemImage: "timer")
                    if let distance = item.distanceKm {
                        Label("\(distance.formatted(.number.precision(.fractionLength(2)))) km", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    }
                }
                .font(.caption).foregroundStyle(ClientClay.secondaryInk)
                if let pace = item.averagePaceMinutesPerKm, let speed = item.averageSpeedKmh {
                    Text("\(ClientActivityFormat.pace(pace)) · \(speed.formatted(.number.precision(.fractionLength(1)))) km/h")
                        .font(.caption.monospacedDigit()).foregroundStyle(ClientClay.inkSoft)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var monthSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClientSectionHeader(title: "Riepilogo del mese", detail: displayedMonth.formatted(.dateTime.month(.wide)).capitalized, symbol: "calendar")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryTile("Palestra", value: "\(monthSummary.gymSessions)", symbol: "dumbbell.fill", tint: ClientClay.accent)
                summaryTile("Corse", value: "\(monthSummary.runs)", symbol: "figure.run", tint: ClientClay.runAccent)
                summaryTile("Km corsi", value: monthSummary.runningDistanceKm > 0 ? monthSummary.runningDistanceKm.formatted(.number.precision(.fractionLength(1))) : "—", symbol: "road.lanes", tint: ClientClay.runAccent)
                summaryTile("Giorni attivi", value: "\(monthSummary.activeDays)", symbol: "calendar.badge.checkmark", tint: ClientClay.sage)
                summaryTile("PB ottenuti", value: "\(monthSummary.personalBests)", symbol: "trophy.fill", tint: ClientClay.gold)
            }
        }
    }

    private func summaryTile(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(tint)
            Text(value).font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit()).foregroundStyle(ClientClay.ink)
        }
        .clayCard(padding: 13)
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ text: String, symbol: String, tint: Color) -> some View {
        Label(text, systemImage: symbol).font(.caption2.weight(.semibold)).foregroundStyle(ClientClay.secondaryInk)
            .symbolRenderingMode(.monochrome).tint(tint)
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
        VStack(alignment: .leading, spacing: 18) {
            ClientPageTitle("Riepilogo", eyebrow: "Costanza e movimento", subtitle: "Solo attività realmente registrate nel periodo.")
            periodSelector
            hero
            metricGrid
            if buckets.isEmpty {
                ClientEmptyState(symbol: "chart.bar.xaxis", title: "Nessuna attività nel periodo", message: "Completa una sessione in palestra o una corsa per vedere il riepilogo.")
            } else {
                if buckets.contains(where: { $0.runningKm > 0 }) {
                    distanceChart
                } else {
                    ClientEmptyState(symbol: "figure.run", title: "Nessuna distanza registrata", message: "Il grafico mostra solo chilometri GPS reali delle corse completate.")
                }
            }
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 4) {
            ForEach(ClientActivityPeriod.allCases) { item in
                Button {
                    period = item
                    ClientHaptics.selection()
                } label: {
                    Text(item.title).font(.caption.weight(.bold)).frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(period == item ? .white : ClientClay.secondaryInk)
                        .background(period == item ? ClientClay.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == item ? [.isSelected] : [])
            }
        }
        .padding(4).background(ClientClay.inset, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ClientClay.border) }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("GIORNI ATTIVI").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.white.opacity(0.64))
                Text("\(summary.activeDays)").font(.system(size: 48, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(.white)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text("TEMPO TOTALE").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.64))
                Text(ClientActivityFormat.compactDuration(summary.activeSeconds)).font(.title2.monospacedDigit().weight(.bold)).foregroundStyle(.white)
            }
        }
        .premiumCard(tint: ClientClay.sage)
    }

    private var metricGrid: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ClientMetricTile(title: "Palestra", value: "\(summary.gymSessions)", detail: "sessioni completate", symbol: "dumbbell.fill", tint: ClientClay.accent)
            ClientMetricTile(title: "Corsa", value: "\(summary.runs)", detail: "uscite registrate", symbol: "figure.run", tint: ClientClay.runAccent)
            ClientMetricTile(title: "Distanza", value: summary.runningDistanceKm > 0 ? "\(summary.runningDistanceKm.formatted(.number.precision(.fractionLength(1)))) km" : "—", detail: "solo GPS reale", symbol: "road.lanes", tint: ClientClay.runAccent)
            ClientMetricTile(title: "Personal Best", value: "\(summary.personalBests)", detail: "ottenuti nel periodo", symbol: "trophy.fill", tint: ClientClay.gold)
        }
    }

    private var distanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClientSectionHeader(title: "Chilometri corsi", detail: "km per periodo", symbol: "chart.xyaxis.line")
            Chart(buckets) { bucket in
                LineMark(
                    x: .value("Periodo", bucket.label),
                    y: .value("Chilometri", bucket.runningKm)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(ClientClay.runAccent)
                PointMark(
                    x: .value("Periodo", bucket.label),
                    y: .value("Chilometri", bucket.runningKm)
                )
                .foregroundStyle(ClientClay.runAccent)
            }
            .frame(height: 170)
            .chartYAxisLabel("km")
            .chartPlotStyle { $0.background(ClientClay.inset.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 12)) }
        }
        .clayCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Grafico dei chilometri corsi nel periodo selezionato")
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
