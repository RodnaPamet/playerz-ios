import PlayerzAPI
import SwiftUI

/// One game as a card: sport and level wish, the day and hours, the court
/// with its players and free places, the club. Tapping the card opens the
/// game; a «+» on the court asks for a place. `status` is the caller's
/// request, on «Моите заявки».
///
/// There is no price and no player levels here: the server sends neither
/// with a game (the court is paid at the club).
struct GameCard: View {
    let game: Components.Schemas.OpenGame
    var status: Components.Schemas.OpenGameRequestStatus?
    /// Where a relative picture address is read from.
    let server: String
    let open: () -> Void
    /// nil when the caller cannot ask: their own game, already asked, closed.
    var join: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            Divider().overlay(Theme.Palette.hairline)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) { whenParts }
                VStack(alignment: .leading, spacing: 2) { whenParts }
            }
            GameCourtView(
                seats: GameSeats(game: game),
                court: GameSport.court(game.sport),
                organiserName: game.booker.firstName,
                organiserAvatar: GameText.picture(game.booker.avatarUrl, server: server),
                join: join
            )
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Theme.Spacing.m) {
                    place
                    Spacer(minLength: 0)
                    spots
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    place
                    spots
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCardSurface()
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        // Not a Button: the «+» inside is one, and a button in a button loses its tap.
        .onTapGesture(perform: open)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameText.spoken(game, status: status))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, open)
        .accessibilityActions {
            if let join {
                Button(String(localized: "games.ask"), action: join)
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.m) {
                sport
                level
                Spacer(minLength: 0)
                badges
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                sport
                level
                badges
            }
        }
    }

    private var sport: some View {
        Label(GameText.sport(game.sport), systemImage: GameSport.symbol(game.sport))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Palette.accentText)
    }

    private var level: some View {
        Label(GameText.level(min: game.levelMin, max: game.levelMax), systemImage: "chart.bar.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private var badges: some View {
        if let status {
            GameStatusBadge(status: status)
        } else if game.viewer?.isBooker == true {
            GameTag(text: String(localized: "games.yours"), systemImage: "star.fill")
        } else if let request = game.viewer?.request?.status, request == .PENDING || request == .ACCEPTED {
            GameStatusBadge(status: request)
        } else if game.viewer?.levelFits == true {
            GameTag(text: String(localized: "games.levelFits"), systemImage: "checkmark.seal.fill")
        }
    }

    @ViewBuilder private var whenParts: some View {
        Text("\(GameText.day(game.startTs, timezone: game.timezone)) | \(GameText.hours(game.startTs, game.endTs, timezone: game.timezone))")
            .font(Theme.Typography.rowTitle)
        Text(GameText.duration(game.startTs, game.endTs))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var place: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(game.venue.name)
                .font(Theme.Typography.rowTitle)
            Label("\(game.courtName) · \(game.venue.city)", systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var spots: some View {
        if game.spotsLeft > 0 {
            Text(String(localized: "games.card.free \(game.spotsLeft)"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.Palette.onAccent)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .background(Theme.Palette.accentFill, in: .rect(cornerRadius: Theme.Radius.tile))
        } else {
            Text(String(localized: "games.card.full"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

extension Components.Schemas.OpenGame {
    /// Whether «Искам да играя» is on offer to the caller, as the game's screen decides it.
    var callerMayAsk: Bool {
        guard open, viewer?.isBooker != true, viewer?.isPlaying != true else { return false }
        switch viewer?.request?.status {
        case .PENDING, .ACCEPTED, .DECLINED, .REMOVED: return false
        default: return true
        }
    }
}
