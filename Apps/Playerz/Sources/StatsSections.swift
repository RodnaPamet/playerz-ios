import Charts
import PlayerzAPI
import SwiftUI

/// A section of «Прогрес»: an icon and a title over a card, as Courtly's
/// Progress page sets them (owner 2026-11-13).
struct StatsSection<Content: View>: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: String, systemImage: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                // The icon gives way at the accessibility sizes, where the
                // title needs the whole width not to break inside a word.
                Group {
                    if typeSize.isAccessibilitySize {
                        Text(title)
                    } else {
                        Label(title, systemImage: systemImage)
                    }
                }
                .font(Theme.Typography.sectionTitle)
                // «Представяне» is one word: past this size it broke inside it.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            BrandContentCard { content }
        }
    }
}

// MARK: - Level

/// The level now, its change over 30 days, and the line it took.
struct StatsLevelCard: View {
    let rating: Components.Schemas.MyStats.ratingPayload

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text(StatsText.level(rating.level))
                    .font(Theme.Typography.display(56, relativeTo: .largeTitle))
                    .monospacedDigit()
                if rating.provisional {
                    BrandBadge(String(localized: "stats.level.provisional"), style: .neutral)
                }
                Spacer(minLength: 0)
                if let change = rating.change30d, rating.matchesRated > 0 {
                    StatsChangeChip(change: change)
                }
            }
            .accessibilityElement(children: .combine)

            if rating.series.count >= 2 {
                StatsLevelChart(rating: rating)
            } else {
                Text(String(localized: rating.matchesRated == 0 ? "stats.level.none" : "stats.level.oneMatch"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.l) {
                if let peak = rating.peak {
                    StatsCaption(String(localized: "stats.level.peak \(StatsText.level(peak.level))"))
                }
                if let start = rating.declaredLevel {
                    StatsCaption(String(localized: "stats.level.start \(start)"))
                }
            }
        }
    }
}

/// «▲ +0,30 за 30 дни» in green, «▼» in red.
struct StatsChangeChip: View {
    let change: Double

    var body: some View {
        let up = change > 0, down = change < 0
        Label {
            Text(String(localized: "stats.level.change30 \(StatsText.change(change))"))
        } icon: {
            Image(systemName: up ? "arrowtriangle.up.fill" : down ? "arrowtriangle.down.fill" : "equal")
        }
        .font(.footnote.weight(.semibold))
        .labelStyle(.titleAndIcon)
        .foregroundStyle(up ? Theme.Palette.success : down ? Theme.Palette.danger : .secondary)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Palette.chipIdle, in: .capsule)
    }
}

struct StatsCaption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(.secondary)
    }
}

/// The level after each counted match: a line over a soft fill, the peak
/// and the last point marked.
struct StatsLevelChart: View {
    let rating: Components.Schemas.MyStats.ratingPayload

    var body: some View {
        let points = rating.series
        let domain = StatsFacts.levelDomain(points.map(\.level))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value(String(localized: "stats.chart.date"), point.at),
                    yStart: .value(String(localized: "stats.level.title"), domain.lowerBound),
                    yEnd: .value(String(localized: "stats.level.title"), point.level)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Palette.accentFill.opacity(0.35), Theme.Palette.accentFill.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value(String(localized: "stats.chart.date"), point.at),
                    y: .value(String(localized: "stats.level.title"), point.level)
                )
                .foregroundStyle(Theme.Palette.accentFill)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(
                    x: .value(String(localized: "stats.chart.date"), last.at),
                    y: .value(String(localized: "stats.level.title"), last.level)
                )
                .foregroundStyle(Theme.Palette.accentFill)
                .symbolSize(80)
                .annotation(position: .top, alignment: .trailing) {
                    Text(StatsText.level(last.level))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Palette.accentFill, in: .capsule)
                        .foregroundStyle(Theme.Palette.onAccent)
                }
            }
            if let peak = rating.peak, peak.level > (points.last?.level ?? 0) {
                RuleMark(y: .value(String(localized: "stats.level.title"), peak.level))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .stride(by: 1)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let level = value.as(Double.self) { Text(StatsText.level(level)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 180)
        // An axis has room for so many letters; VoiceOver reads the summary.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "stats.chart.level"))
        .accessibilityValue(summary)
    }

    /// What VoiceOver says for the line: where it started, where it is, its peak.
    private var summary: String {
        guard let first = rating.series.first, let last = rating.series.last else { return "" }
        return String(
            localized: "stats.chart.level.summary \(StatsText.level(first.level)) \(StatsText.level(last.level)) \(rating.series.count)"
        )
    }
}

// MARK: - Form and performance

/// The last results as letters in circles, newest first, and the streak.
struct StatsFormRow: View {
    let form: [Components.Schemas.MyStats.formPayloadPayload]
    let streak: Components.Schemas.MyStats.performancePayload.currentStreakPayload?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ViewThatFits(in: .horizontal) {
                circles(spacing: Theme.Spacing.s)
                circles(spacing: 3)
            }
            if let streak {
                Text(StatsText.streak(streak.outcome.rawValue, streak.length))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "stats.form.title"))
        .accessibilityValue(
            form.map { StatsText.outcome($0.outcome.rawValue) }.formatted(.list(type: .and))
                + (streak.map { ". " + StatsText.streak($0.outcome.rawValue, $0.length) } ?? "")
        )
    }

    private func circles(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(form.enumerated()), id: \.offset) { _, item in
                let outcome = item.outcome.rawValue
                Text(StatsText.letter(outcome))
                    .font(.footnote.weight(.heavy))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(outcome == "DRAW" ? Color.primary : Theme.Palette.onAccent)
                    .background(color(outcome), in: .circle)
            }
        }
    }

    private func color(_ outcome: String) -> Color {
        switch outcome {
        case "WIN": Theme.Palette.success
        case "LOSS": Theme.Palette.danger
        default: Theme.Palette.chipIdle
        }
    }
}

/// One figure of «Представяне»: a big number and its name.
struct StatsFigure: View {
    let value: String
    let label: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.Typography.display(40, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Six figures in two rows of three; one column at the largest text sizes.
struct StatsPerformanceGrid: View {
    let performance: Components.Schemas.MyStats.performancePayload
    let change: Double?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Theme.Spacing.m, alignment: .leading),
            count: typeSize.isAccessibilitySize ? 1 : 3
        )
        LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.l) {
            StatsFigure(value: "\(performance.wins)", label: String(localized: "stats.performance.wins"))
            StatsFigure(value: "\(performance.losses)", label: String(localized: "stats.performance.losses"))
            StatsFigure(
                value: performance.winRate.map { StatsText.percent(Int(($0 * 100).rounded())) } ?? "–",
                label: String(localized: "stats.performance.winRate")
            )
            StatsFigure(value: "\(performance.games)", label: String(localized: "stats.performance.games"))
            StatsFigure(value: "\(performance.bestWinStreak)", label: String(localized: "stats.performance.bestStreak"))
            StatsFigure(
                value: change.map(StatsText.change) ?? "–",
                label: String(localized: "stats.performance.levelChange"),
                tint: (change ?? 0) > 0 ? Theme.Palette.success : (change ?? 0) < 0 ? Theme.Palette.danger : .primary
            )
        }
    }
}

// MARK: - Sets and games

/// Won against lost as one bar: green for the caller's share.
struct StatsRatioBar: View {
    let title: String
    let won: Int
    let lost: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(localized: "stats.sets.ratio \(won) \(lost)"))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                let total = max(won + lost, 1)
                HStack(spacing: 2) {
                    Capsule().fill(Theme.Palette.success)
                        .frame(width: max(0, proxy.size.width * CGFloat(won) / CGFloat(total) - 1))
                    Capsule().fill(Theme.Palette.danger.opacity(0.75))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatsSetsCard: View {
    let sets: Components.Schemas.MyStats.setsPayload

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            StatsRatioBar(title: String(localized: "stats.sets.sets"), won: sets.setsWon, lost: sets.setsLost)
            StatsRatioBar(title: String(localized: "stats.sets.games"), won: sets.gamesWon, lost: sets.gamesLost)
            if sets.closeSetsWon + sets.closeSetsLost > 0 {
                StatsRatioBar(
                    title: String(localized: "stats.sets.close"),
                    won: sets.closeSetsWon,
                    lost: sets.closeSetsLost
                )
            }
        }
    }
}

// MARK: - People

/// Partners or rivals: a name, matches, wins and the share won. No
/// pictures: the name needs the row's width more (Courtly's table has none).
struct StatsPeopleTable: View {
    let rows: [Components.Schemas.StatsPersonRecord]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize { stacked } else { table }
    }

    /// At the accessibility sizes three columns of numbers do not fit beside a
    /// name: each person is a name over one line of their figures.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            ForEach(rows, id: \.person.userId) { row in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(StatsText.name(row.person)).font(.body.weight(.semibold))
                    Text(String(localized: "stats.people.spoken \(row.games) \(row.wins)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var table: some View {
        VStack(spacing: Theme.Spacing.m) {
            HStack {
                Spacer()
                header(String(localized: "stats.col.games"))
                header(String(localized: "stats.col.wins"))
                header(String(localized: "stats.col.rate"))
            }
            .accessibilityHidden(true)
            ForEach(rows, id: \.person.userId) { row in
                HStack(spacing: Theme.Spacing.s) {
                    Text(StatsText.name(row.person))
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Theme.Spacing.s)
                    cell("\(row.games)")
                    cell("\(row.wins)")
                    cell(StatsFacts.percent(row.wins, of: row.games).map(StatsText.percent) ?? "–", bold: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(StatsText.name(row.person))
                .accessibilityValue(String(localized: "stats.people.spoken \(row.games) \(row.wins)"))
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
    }

    private func cell(_ text: String, bold: Bool = false) -> some View {
        Text(text)
            .font(bold ? .body.weight(.bold) : .body)
            .monospacedDigit()
            .frame(width: 56, alignment: .trailing)
    }
}

// MARK: - Standing

struct StatsStandingCard: View {
    let standing: Components.Schemas.MyStats.standingPayload
    let session: SessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(standing.club.name).font(Theme.Typography.rowTitle)
                Spacer()
                if let rank = standing.rank {
                    Text(String(localized: "stats.standing.rank \(rank) \(standing.total)"))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.Palette.accentText)
                }
            }
            if let note = absentNote {
                Text(note).font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(standing.rows, id: \.userId) { row in
                HStack(spacing: Theme.Spacing.m) {
                    Text("\(row.rank)")
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 28, alignment: .leading)
                    BrandAvatar(name: row.name, url: session.mediaURL(row.avatarUrl), side: 32)
                    Text(row.isYou ? String(localized: "stats.standing.you") : (row.name ?? String(localized: "stats.unnamed")))
                        .font(.body.weight(row.isYou ? .heavy : .regular))
                        .lineLimit(1)
                    Spacer()
                    Text(StatsText.level(row.level)).font(.headline.monospacedDigit())
                }
                .padding(.vertical, Theme.Spacing.xs)
                .padding(.horizontal, row.isYou ? Theme.Spacing.s : 0)
                .background(row.isYou ? Theme.Palette.accentFill.opacity(0.14) : .clear, in: .rect(cornerRadius: 12))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var absentNote: String? {
        guard standing.rank == nil else { return nil }
        switch standing.absent {
        case "HIDDEN": return String(localized: "stats.standing.hidden")
        case "PROVISIONAL": return String(localized: "stats.standing.provisional")
        default: return String(localized: "stats.standing.below")
        }
    }
}

// MARK: - Activity

struct StatsActivityCard: View {
    let activity: Components.Schemas.MyStats.activityPayload

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            StatsCaption(String(localized: "stats.activity.months"))
            Chart {
                ForEach(activity.months, id: \.month) { month in
                    if let date = StatsText.month(month.month) {
                        BarMark(
                            x: .value(String(localized: "stats.chart.month"), date, unit: .month),
                            y: .value(String(localized: "stats.performance.games"), month.games)
                        )
                        .foregroundStyle(Theme.Palette.accentFill.gradient)
                        .cornerRadius(4)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { value in
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) { Text(StatsText.monthShort(date)) }
                    }
                }
            }
            .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
            .frame(height: 140)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "stats.activity.months"))
            .accessibilityValue(monthsSummary)

            StatsCaption(String(localized: "stats.activity.weekdays"))
            // The bars in a fixed height, their letters under them at any size.
            VStack(spacing: Theme.Spacing.xs) {
                let top = max(activity.weekdays.max() ?? 0, 1)
                HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                    ForEach(Array(activity.weekdays.enumerated()), id: \.offset) { _, count in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(count == top && count > 0 ? Theme.Palette.accentFill : Theme.Palette.chipIdle)
                            .frame(height: max(4, 56 * CGFloat(count) / CGFloat(top)))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 56, alignment: .bottom)
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(StatsText.weekdayInitial(index))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityHidden(true)

            if let day = StatsFacts.busiest(activity.weekdays), let hour = StatsFacts.busiestTwoHours(activity.hours) {
                Text(String(localized: "stats.activity.favourite \(StatsText.weekday(day)) \(hour) \((hour + 2) % 24)"))
                    .font(.subheadline.weight(.semibold))
            }

            if !activity.venues.isEmpty {
                StatsCaption(String(localized: "stats.activity.venues"))
                ForEach(activity.venues, id: \.value1.id) { venue in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(venue.value1.name).font(.body.weight(.semibold))
                            Text(CityText.shown(venue.value1.cityNames)).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(localized: "stats.activity.venueRecord \(venue.value2.games) \(venue.value2.wins)"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var monthsSummary: String {
        let total = activity.months.reduce(0) { $0 + $1.games }
        return String(localized: "stats.activity.months.summary \(total)")
    }
}

// MARK: - Milestones

struct StatsMilestones: View {
    let milestones: [Components.Schemas.StatsMilestone]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shown = milestones.compactMap(Self.face)
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.m), count: typeSize.isAccessibilitySize ? 1 : 2),
            spacing: Theme.Spacing.m
        ) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, face in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Image(systemName: face.symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.Palette.accentText)
                        .accessibilityHidden(true)
                    Text(face.value)
                        .font(Theme.Typography.display(32, relativeTo: .title2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(face.title).font(.footnote.weight(.semibold))
                    if let detail = face.detail {
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.chipIdle.opacity(0.6), in: .rect(cornerRadius: Theme.Radius.tile))
                .accessibilityElement(children: .combine)
            }
        }
    }

    struct Face {
        let symbol: String
        let value: String
        let title: String
        let detail: String?
    }

    /// A known kind's face; a kind this build does not know is not shown.
    static func face(_ m: Components.Schemas.StatsMilestone) -> Face? {
        let when = m.at.map(StatsText.date)
        switch m.kind {
        case "PEAK_LEVEL":
            return Face(symbol: "chart.line.uptrend.xyaxis", value: StatsText.level(m.value),
                        title: String(localized: "stats.milestone.peak"), detail: when)
        case "BEST_WIN_STREAK":
            return Face(symbol: "flame.fill", value: "\(Int(m.value))",
                        title: String(localized: "stats.milestone.streak"), detail: when)
        case "MATCHES_PLAYED":
            return Face(symbol: "trophy.fill", value: "\(Int(m.value))",
                        title: String(localized: "stats.milestone.matches"), detail: when)
        case "TOP_PARTNER":
            return Face(symbol: "person.2.fill", value: m.person.map(StatsText.name) ?? "–",
                        title: String(localized: "stats.milestone.partner"),
                        detail: String(localized: "stats.milestone.partnerGames \(Int(m.value))"))
        case "CLUBS_WON_AT":
            return Face(symbol: "building.2.fill", value: "\(Int(m.value))",
                        title: String(localized: "stats.milestone.clubs"), detail: when)
        case "FIRST_WIN":
            return Face(symbol: "star.fill", value: when ?? "–",
                        title: String(localized: "stats.milestone.firstWin"), detail: nil)
        default:
            return nil
        }
    }
}

// MARK: - The questionnaire's card

/// «Вземи начално ниво»: the accent card that opens the questionnaire.
struct StatsSurveyCard: View {
    let questions: Int
    let again: Bool
    let start: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(String(localized: again ? "survey.card.again" : "survey.card.title"))
                .font(Theme.Typography.display(32, relativeTo: .title2))
            Text(String(localized: "survey.card.subtitle \(questions)"))
                .font(.subheadline.weight(.semibold))
            Button(action: start) {
                Label(String(localized: "survey.card.button"), systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.brandPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .background(
            LinearGradient(
                colors: [Theme.Palette.accentFill.opacity(0.22), Theme.Palette.accentFill.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: Theme.Radius.card)
        )
    }
}
