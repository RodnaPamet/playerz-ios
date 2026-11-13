import PlayerzAPI
import SwiftUI

/// «Профил» → «Прогрес» (playerz-ios#95): the questionnaire while there is no
/// counted match, the level and its line, form, performance, sets and
/// games, the club standing, partners and rivals, activity, milestones.
struct StatsProgressView: View {
    let model: StatsModel
    let session: SessionModel
    let openSurvey: (Components.Schemas.SkillSurvey) -> Void

    var body: some View {
        switch model.phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "stats.failed")) {
                Button(String(localized: "venues.retry")) { Task { await model.load(session) } }
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded:
            ScrollViewReader { proxy in
                ScrollView { content.padding(.horizontal, Theme.Spacing.l).padding(.bottom, Theme.Spacing.xl) }
                    .refreshable { await model.load(session) }
                    // DEBUG only (`PLAYERZ_STATS_AT`): a section on top, for a screenshot.
                    .task {
                        if let section = DebugLaunch.statsAt { proxy.scrollTo(section, anchor: .top) }
                    }
            }
        }
    }

    @ViewBuilder private var content: some View {
        let stats = model.stats
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            if model.offersSurvey, let survey = model.survey {
                StatsSurveyCard(questions: survey.questions.count, again: stats?.rating?.declaredLevel != nil) {
                    openSurvey(survey)
                }
            }

            if let rating = stats?.rating {
                StatsSection(String(localized: "stats.level.title"), systemImage: "chart.line.uptrend.xyaxis") {
                    StatsLevelCard(rating: rating)
                }
            }

            if let stats, stats.performance.games > 0 {
                StatsSection(String(localized: "stats.form.title"), systemImage: "bolt.fill") {
                    StatsFormRow(form: stats.form, streak: stats.performance.currentStreak)
                }
                StatsSection(String(localized: "stats.performance.title"), systemImage: "chart.bar.fill") {
                    StatsPerformanceGrid(performance: stats.performance, change: stats.rating?.change30d)
                }
                .id("performance")
                if let standing = stats.standing {
                    StatsSection(String(localized: "stats.standing.title"), systemImage: "trophy") {
                        StatsStandingCard(standing: standing, session: session)
                    }
                    .id("standing")
                }
                if let sets = stats.sets {
                    StatsSection(String(localized: "stats.sets.title"), systemImage: "square.split.2x1") {
                        StatsSetsCard(sets: sets)
                    }
                    .id("sets")
                }
                if !stats.partners.isEmpty {
                    StatsSection(
                        String(localized: "stats.partners.title"),
                        systemImage: "person.2",
                        subtitle: String(localized: "stats.partners.subtitle")
                    ) {
                        StatsPeopleTable(rows: stats.partners)
                    }
                    .id("partners")
                }
                if !stats.rivals.isEmpty {
                    StatsSection(
                        String(localized: "stats.rivals.title"),
                        systemImage: "figure.fencing",
                        subtitle: String(localized: "stats.rivals.subtitle")
                    ) {
                        StatsPeopleTable(rows: stats.rivals)
                    }
                    .id("rivals")
                }
                StatsSection(String(localized: "stats.activity.title"), systemImage: "calendar") {
                    StatsActivityCard(activity: stats.activity)
                }
                .id("activity")
                if stats.milestones.contains(where: { StatsMilestones.face($0) != nil }) {
                    StatsSection(String(localized: "stats.milestones.title"), systemImage: "rosette") {
                        StatsMilestones(milestones: stats.milestones)
                    }
                }
            } else {
                BrandEmptyState(
                    systemImage: "chart.xyaxis.line",
                    title: String(localized: "stats.empty.title"),
                    message: String(localized: "stats.empty.hint")
                )
                .frame(minHeight: 260)
            }
        }
    }
}
