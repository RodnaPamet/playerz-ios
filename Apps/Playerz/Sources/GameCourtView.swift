import PlayerzAPI
import SwiftUI

/// A game's court, drawn: the organiser and the players on their sides, a
/// round «+» for every place still wanted. `join` nil shows the free places
/// without offering them (the caller already asked, or the game is theirs).
struct GameCourtView: View {
    let seats: GameSeats
    /// The game's sport, drawn as its own surface (SportPitch).
    let sport: String
    /// The only player the server names (#376).
    var organiserName: String?
    var organiserAvatar: URL?
    var large = false
    var join: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var seatBase: CGFloat = 48

    /// One column a side for singles and doubles, two for a team.
    private var columns: Int { max(seats.left.count, seats.right.count) <= 2 ? 1 : 2 }

    /// Grows with the text size, but four across must still fit a small phone.
    private var seat: CGFloat {
        min(seatBase * (large ? 1.25 : 1), columns == 1 ? 80 : 56)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 0) {
                side(seats.left)
                side(seats.right)
            }
            .padding(.vertical, Theme.Spacing.l)
            // A singles court is still a court, not a strip.
            .frame(minHeight: seat * 2 + Theme.Spacing.l * 2)
            .background { surface }
            if seats.hidden > 0 {
                Text(String(localized: "games.court.more \(seats.hidden)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var surface: some View {
        // A shade over the surface keeps the players' pictures readable on
        // the brighter ones (clay, sand, a basketball floor).
        SportPitchView(sport: sport)
            .overlay(Color.black.opacity(0.18))
            .clipShape(.rect(cornerRadius: Theme.Radius.tile))
    }

    private func side(_ side: [GameSeats.Seat]) -> some View {
        let rows = stride(from: 0, to: side.count, by: columns).map { Array(side[$0..<min($0 + columns, side.count)]) }
        return VStack(spacing: Theme.Spacing.m) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: Theme.Spacing.m) {
                    ForEach(rows[row].indices, id: \.self) { index in
                        seatView(rows[row][index])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func seatView(_ kind: GameSeats.Seat) -> some View {
        switch kind {
        case .organiser(let isYou):
            face
                .overlay(alignment: .bottomTrailing) { mark(isYou ? "checkmark" : "star.fill") }
                .accessibilityHidden(true)
        case .you:
            Circle()
                .fill(Theme.Palette.onHeader)
                .frame(width: seat, height: seat)
                .overlay {
                    Text(String(localized: "games.seat.you"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.Palette.headerInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 4)
                }
                .overlay(alignment: .bottomTrailing) { mark("checkmark") }
                .accessibilityHidden(true)
        case .player(let person):
            portrait(name: person.name, picture: person.picture)
                .overlay(alignment: .bottom) {
                    if let level = person.level {
                        Text(level)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.Palette.headerInk)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Theme.Palette.onHeader, in: .capsule)
                            .overlay(Capsule().strokeBorder(Theme.Palette.headerInk.opacity(0.2)))
                            .offset(y: seat * 0.18)
                    }
                }
                .accessibilityHidden(true)
        case .taken:
            Circle()
                .fill(Theme.Palette.onHeader.opacity(0.85))
                .frame(width: seat, height: seat)
                .overlay { symbol("person.fill", color: Theme.Palette.headerInk) }
                .accessibilityHidden(true)
        case .open:
            if let join {
                Button(action: join) {
                    Circle()
                        .fill(Theme.Palette.onHeader)
                        .frame(width: seat, height: seat)
                        .overlay { symbol("plus", color: Theme.Palette.headerInk) }
                        .contentShape(.circle)
                }
                .buttonStyle(.brandCard)
                .accessibilityLabel(String(localized: "games.ask"))
            } else {
                // Free, but not for the caller to ask for: an outline, no button.
                Circle()
                    .strokeBorder(Theme.Palette.onHeader.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: seat, height: seat)
                    .overlay { symbol("plus", color: Theme.Palette.onHeader.opacity(0.85)) }
                    .accessibilityHidden(true)
            }
        case .closed:
            Circle()
                .fill(Theme.Palette.onHeader.opacity(0.14))
                .frame(width: seat, height: seat)
                .accessibilityHidden(true)
        }
    }

    /// The organiser: their picture, their initial, or a figure when the
    /// server gives neither.
    private var face: some View {
        portrait(name: organiserName, picture: organiserAvatar)
    }

    private func portrait(name: String?, picture: URL?) -> some View {
        Circle()
            .fill(Theme.Palette.onHeader)
            .frame(width: seat, height: seat)
            .overlay {
                if let initial = name?.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: seat * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.headerInk)
                } else {
                    symbol("person.fill", color: Theme.Palette.headerInk)
                }
            }
            .overlay {
                if let picture {
                    AsyncImage(url: picture) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: seat, height: seat)
                    .clipShape(.circle)
                }
            }
    }

    // Sized from the seat, which already follows the text size.
    private func symbol(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: seat * 0.4, weight: .bold))
            .foregroundStyle(color)
    }

    /// The small disc on a seat: a star for the organiser, a tick for the caller.
    private func mark(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: seat * 0.2, weight: .heavy))
            .foregroundStyle(Theme.Palette.onHeader)
            .frame(width: seat * 0.4, height: seat * 0.4)
            .background(Theme.Palette.headerInk, in: .circle)
            .overlay(Circle().strokeBorder(Theme.Palette.onHeader, lineWidth: 1.5))
            .offset(x: seat * 0.08, y: seat * 0.08)
    }
}


#Preview("Doubles") {
    GameCourtView(
        seats: GameSeats(capacity: 4, players: 2, spotsLeft: 1, viewerIsBooker: false, viewerIsPlaying: false),
        sport: "TENNIS", organiserName: "Мария"
    ) {}
    .padding()
}

#Preview("Singles") {
    GameCourtView(
        seats: GameSeats(capacity: 2, players: 1, spotsLeft: 1, viewerIsBooker: true, viewerIsPlaying: false),
        sport: "PADEL", organiserName: "Иван", large: true
    )
    .padding()
}

#Preview("Team") {
    GameCourtView(
        seats: GameSeats(capacity: 14, players: 6, spotsLeft: 4, viewerIsBooker: false, viewerIsPlaying: true),
        sport: "FOOTBALL5", organiserName: nil
    ) {}
    .padding()
}
