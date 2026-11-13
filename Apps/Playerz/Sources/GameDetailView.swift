import PlayerzAPI
import SwiftUI

/// One game (#510): its court and players, its facts, and what the caller can
/// do about it: ask for a place, take the request back, or leave before the
/// club's cutoff.
struct GameDetailView: View {
    @State private var game: Components.Schemas.OpenGame
    @Bindable var session: SessionModel
    /// The list behind this screen re-reads after a change.
    let changed: () async -> Void

    init(
        game: Components.Schemas.OpenGame,
        session: SessionModel,
        changed: @escaping () async -> Void
    ) {
        _game = State(initialValue: game)
        self.session = session
        self.changed = changed
    }

    @State private var asking = false
    @State private var busy = false
    @State private var problem: String?

    @ScaledMetric(relativeTo: .body) private var faceSide: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At the accessibility sizes a pinned button would cover half the
    /// screen, so there it follows the court in the scrolling content.
    private var pinsAction: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                summary
                if !pinsAction { actionBar }
                players
                facts
                if let text = game.note, !text.isEmpty {
                    BrandContentCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(String(localized: "games.detail.note"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(text)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
        .brandPage()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pinsAction {
                actionBar
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                    .background(Theme.Palette.page)
                    .overlay(alignment: .top) { divider }
            }
        }
        .navigationTitle(GameText.sport(game.sport))
        .brandHeader(.back(GameText.sport(game.sport)))
        // The bottom of this screen is its own button.
        .floatingTabBarHidden()
        .onChange(of: problem) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
        .brandSheet(isPresented: $asking, detents: [.medium, .large]) {
            GameAskSheet(game: game, session: session) { outcome in
                asking = false
                switch outcome {
                case .asked(let fresh):
                    game = fresh
                    problem = nil
                    Task { await changed() }
                case .refused(let text):
                    problem = text
                    Task { await changed() }
                case .cancelled:
                    break
                }
            }
        }
    }

    // ─── When, the court, where ───────────────────────────────────────

    private var summary: some View {
        BrandContentCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if game.viewer?.levelFits == true {
                        GameTag(text: String(localized: "games.levelFits"), systemImage: "checkmark.seal.fill")
                    }
                    Text(GameText.day(game.startTs, timezone: game.timezone))
                        .font(Theme.Typography.cardTitle)
                    Text("\(GameText.hours(game.startTs, game.endTs, timezone: game.timezone)) · \(GameText.duration(game.startTs, game.endTs))")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                // One sentence for VoiceOver; the court's «+» is the button below.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(GameText.spoken(game))
                GameCourtView(
                    seats: GameSeats(game: game, server: session.serverURL),
                    sport: game.sport,
                    organiserName: game.booker.firstName,
                    organiserAvatar: GameText.picture(game.booker.avatarUrl, server: session.serverURL),
                    large: true,
                    join: game.callerMayAsk && !busy ? { asking = true } : nil
                )
                .accessibilityHidden(true)
            }
        }
    }

    // ─── Играчи ───────────────────────────────────────────────────────

    private var players: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "games.detail.players"))
                    .font(Theme.Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(String(localized: "games.players \(game.playersCount) \(game.capacity)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            BrandContentCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    playerRow(
                        initial: game.booker.firstName?.first,
                        symbol: "person.fill",
                        title: game.booker.firstName ?? String(localized: "games.organiserUnknown"),
                        subtitle: game.viewer?.isBooker == true
                            ? String(localized: "games.yours")
                            : String(localized: "games.detail.organiser")
                    )
                    let others = max(game.playersCount - 1, 0)
                    let named = Array((game.players ?? []).dropFirst())
                    let callerPlays = named.isEmpty && game.viewer?.isPlaying == true && game.viewer?.isBooker != true && others > 0
                    // Named to the booker, the players and whoever asked (projectZ#676).
                    ForEach(named.indices, id: \.self) { i in
                        divider
                        playerRow(
                            initial: named[i].isYou ? nil : named[i].firstName?.first,
                            symbol: named[i].isYou ? "checkmark" : "person.fill",
                            title: named[i].isYou
                                ? String(localized: "games.seat.you")
                                : named[i].firstName ?? String(localized: "games.organiserUnknown"),
                            subtitle: named[i].level.map {
                                String(localized: "games.detail.level \($0.formatted(.number.precision(.fractionLength(1))))")
                            }
                        )
                    }
                    if callerPlays {
                        divider
                        playerRow(symbol: "checkmark", title: String(localized: "games.seat.you"),
                                  subtitle: GameText.status(.ACCEPTED))
                    }
                    // Those the server counts and does not name to this viewer.
                    let unnamed = others - named.count - (callerPlays ? 1 : 0)
                    if unnamed > 0 {
                        divider
                        playerRow(symbol: "person.2.fill",
                                  title: String(localized: "games.detail.others \(unnamed)"))
                    }
                    if game.spotsLeft > 0 {
                        divider
                        playerRow(symbol: "plus", title: String(localized: "games.card.free \(game.spotsLeft)"), wanted: true)
                    }
                }
            }
        }
    }

    private var divider: some View { Divider().overlay(Theme.Palette.hairline) }

    private func playerRow(
        initial: Character? = nil,
        symbol: String,
        title: String,
        subtitle: String? = nil,
        wanted: Bool = false
    ) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Group {
                if let initial {
                    Text(String(initial).uppercased()).font(.headline)
                } else {
                    Image(systemName: symbol).font(.subheadline.weight(.bold))
                }
            }
            .foregroundStyle(wanted ? Theme.Palette.accentText : Color.primary)
            .frame(width: faceSide, height: faceSide)
            .background {
                if wanted {
                    Circle().strokeBorder(Theme.Palette.accentText, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                } else {
                    Circle().fill(Theme.Palette.chipIdle)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.Typography.rowTitle)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // ─── Къде, корт, ниво, срок ───────────────────────────────────────

    private var facts: some View {
        BrandContentCard {
            VStack(spacing: Theme.Spacing.m) {
                LabeledContent(String(localized: "games.detail.where"), value: "\(game.venue.name), \(CityText.shown(game.venue.cityNames))")
                divider
                LabeledContent(String(localized: "games.detail.court"), value: game.courtName)
                LabeledContent(String(localized: "games.detail.price"), value: GameText.money(game))
                divider
                LabeledContent(String(localized: "games.detail.level"),
                               value: GameText.level(min: game.levelMin, max: game.levelMax))
                divider
                LabeledContent(String(localized: "games.detail.cutoff"),
                               value: GameText.when(game.cutoffAt, timezone: game.timezone))
            }
        }
    }

    // ─── The caller's part ────────────────────────────────────────────

    private var actionBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            action
            Text(String(localized: "games.detail.payAtClub"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// None yet, a request, a place, or the organiser's own game.
    @ViewBuilder private var action: some View {
        let viewer = game.viewer
        if viewer?.isBooker == true {
            Label(String(localized: "games.yours"), systemImage: "star.fill")
                .font(Theme.Typography.rowTitle)
        } else if let request = viewer?.request, request.status == .PENDING || request.status == .ACCEPTED {
            requestLine(request.status)
            // Leaving is possible until the club's cutoff; waiting can be withdrawn any time.
            if request.status == .PENDING || game.cutoffAt > .now {
                Button(role: .destructive) {
                    Task { await withdraw(request.id) }
                } label: {
                    Text(request.status == .PENDING
                         ? String(localized: "games.withdraw")
                         : String(localized: "games.leave"))
                }
                .buttonStyle(.brandSecondary)
                .disabled(busy)
            }
        } else if game.open {
            if let request = viewer?.request { requestLine(request.status) }
            Button(String(localized: "games.ask")) { asking = true }
                .buttonStyle(.brandPrimary)
                .disabled(busy || !game.callerMayAsk)
        } else {
            Text(String(localized: "games.error.GAME_CLOSED"))
                .foregroundStyle(.secondary)
        }
    }

    private func requestLine(_ status: Components.Schemas.OpenGameRequestStatus) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(String(localized: "games.detail.request")).font(.subheadline)
                Spacer()
                GameStatusBadge(status: status)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(String(localized: "games.detail.request")).font(.subheadline)
                GameStatusBadge(status: status)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func withdraw(_ requestId: String) async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        do {
            let response = try await client.withdrawGameRequest(path: .init(id: requestId))
            if case .noContent = response {
                await reload()
                await changed()
            } else {
                problem = GameText.error(apiErrorCode(response))
            }
        } catch {
            problem = GameText.error(nil)
        }
    }

    private func reload() async {
        guard let client = await session.client() else { return }
        if let fresh = try? await client.getOpenGame(path: .init(id: game.id)).ok.body.json.data {
            game = fresh
        }
    }
}
