import PlayerzAPI
import SwiftUI

/// Профил, the stats home (playerz-ios#95; owner 2026-11-13, from Courtly's
/// Progress page: "a personal stat aficionado delight"). The sport on a pill
/// in the header, «Прогрес» | «Мачове» under it, and everything the account
/// can set behind the gear (`ProfileSettingsView`).
struct ProfileView: View {
    @Bindable var session: SessionModel
    @State private var model = StatsModel()
    @State private var showing: Showing = DebugLaunch.statsMatches ? .matches : .progress
    /// A DEBUG launch for one of the settings screens opens them first.
    @State private var path: [Route] = DebugLaunch.profile == nil ? [] : [.settings]
    @State private var pickingSport = false
    @State private var surveying: SurveyTarget?

    enum Showing: Hashable { case progress, matches }
    enum Route: Hashable { case settings }

    struct SurveyTarget: Identifiable {
        let survey: Components.Schemas.SkillSurvey
        var id: String { survey.sport }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch showing {
                case .progress:
                    StatsProgressView(model: model, session: session) { open($0) }
                case .matches:
                    StatsMatchesView(model: model, session: session)
                }
            }
            .brandPage()
            // Hidden with the system bar, but still what a pushed screen's back button says.
            .navigationTitle(String(localized: "profile.title"))
            .brandChipBar {
                BrandChipRow {
                    BrandChip(String(localized: "stats.tab.progress"), isSelected: showing == .progress) {
                        showing = .progress
                    }
                    BrandChip(String(localized: "stats.tab.matches"), isSelected: showing == .matches) {
                        showing = .matches
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "stats.tabs"))
            }
            .brandHeader(.title(String(localized: "profile.title"))) {
                if let sport = model.shownSport {
                    BrandHeaderPill(
                        title: GameText.sport(sport),
                        systemImage: GameSport.symbol(sport),
                        showsChevron: model.offeredSports.count > 1
                    ) { pickingSport = true }
                    .disabled(model.offeredSports.count < 2)
                }
            } actions: {
                BrandHeaderButton(systemImage: "gearshape", label: String(localized: "profile.settings")) {
                    path.append(.settings)
                }
                BrandHeaderActions(session: session)
            }
            .navigationDestination(for: Route.self) { _ in
                ProfileSettingsView(session: session)
            }
            .brandSheet(isPresented: $pickingSport) { sportSheet }
            .sheet(item: $surveying) { target in
                SkillSurveyView(survey: target.survey) { answers in
                    await model.submit(answers, sport: target.survey.sport, session)
                } done: {
                    surveying = nil
                    Task { await reload() }
                }
                .outsideShellBar()
            }
        }
        .task {
            if let sport = DebugLaunch.statsSport { model.sport = sport }
            await reload()
            if DebugLaunch.survey, let survey = model.survey { surveying = SurveyTarget(survey: survey) }
        }
        .onChange(of: showing) { _, now in
            if now == .matches { Task { await model.loadMatches(session) } }
        }
        .onChange(of: model.sport) { Task { await reload() } }
        // Back on this tab: a result entered elsewhere is in the figures.
        .onShellTabReturn { await reload() }
    }

    private func reload() async {
        await model.load(session)
        if showing == .matches { await model.loadMatches(session) }
    }

    private func open(_ survey: Components.Schemas.SkillSurvey) {
        surveying = SurveyTarget(survey: survey)
    }

    private var sportSheet: some View {
        BrandDarkSheet(
            title: String(localized: "stats.sport.title"),
            subtitle: String(localized: "stats.sport.subtitle")
        ) {
            ForEach(model.offeredSports, id: \.self) { sport in
                BrandSheetRow(
                    title: GameText.sport(sport),
                    systemImage: GameSport.symbol(sport),
                    isSelected: model.shownSport == sport
                ) {
                    pickingSport = false
                    model.sport = sport
                }
            }
        }
    }
}
