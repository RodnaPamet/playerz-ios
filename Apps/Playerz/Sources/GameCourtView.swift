import PlayerzAPI
import SwiftUI

/// A game's court, drawn: the organiser and the players on their sides, a
/// round «+» for every place still wanted. `join` nil shows the free places
/// without offering them (the caller already asked, or the game is theirs).
struct GameCourtView: View {
    let seats: GameSeats
    let court: GameSport.Court
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
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.tile)
                .fill(
                    LinearGradient(
                        colors: [Theme.Palette.headerGlow, Theme.Palette.controlOn],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            CourtLines(court: court)
                .stroke(Theme.Palette.onHeader.opacity(0.5), lineWidth: 1.5)
            if court == .net {
                Capsule()
                    .fill(Theme.Palette.onHeader.opacity(0.9))
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }
        }
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
        Circle()
            .fill(Theme.Palette.onHeader)
            .frame(width: seat, height: seat)
            .overlay {
                if let initial = organiserName?.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: seat * 0.42, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Palette.headerInk)
                } else {
                    symbol("person.fill", color: Theme.Palette.headerInk)
                }
            }
            .overlay {
                if let organiserAvatar {
                    AsyncImage(url: organiserAvatar) { image in
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

/// The markings of a court seen from above, the net or halfway line upright
/// in the middle.
private struct CourtLines: Shape {
    let court: GameSport.Court

    func path(in rect: CGRect) -> Path {
        let field = rect.insetBy(dx: 8, dy: 8)
        var path = Path()
        path.addRect(field)
        switch court {
        case .net:
            // Service lines, and the line that halves the service boxes.
            let near = field.minX + field.width * 0.2
            let far = field.minX + field.width * 0.8
            path.move(to: CGPoint(x: near, y: field.minY))
            path.addLine(to: CGPoint(x: near, y: field.maxY))
            path.move(to: CGPoint(x: far, y: field.minY))
            path.addLine(to: CGPoint(x: far, y: field.maxY))
            path.move(to: CGPoint(x: near, y: field.midY))
            path.addLine(to: CGPoint(x: far, y: field.midY))
        case .pitch:
            path.move(to: CGPoint(x: field.midX, y: field.minY))
            path.addLine(to: CGPoint(x: field.midX, y: field.maxY))
            let radius = field.height * 0.2
            path.addEllipse(in: CGRect(x: field.midX - radius, y: field.midY - radius, width: radius * 2, height: radius * 2))
            let box = CGSize(width: field.width * 0.1, height: field.height * 0.5)
            path.addRect(CGRect(x: field.minX, y: field.midY - box.height / 2, width: box.width, height: box.height))
            path.addRect(CGRect(x: field.maxX - box.width, y: field.midY - box.height / 2, width: box.width, height: box.height))
        case .plain:
            path.move(to: CGPoint(x: field.midX, y: field.minY))
            path.addLine(to: CGPoint(x: field.midX, y: field.maxY))
        }
        return path
    }
}

#Preview("Doubles") {
    GameCourtView(
        seats: GameSeats(capacity: 4, players: 2, spotsLeft: 1, viewerIsBooker: false, viewerIsPlaying: false),
        court: .net, organiserName: "Мария"
    ) {}
    .padding()
}

#Preview("Singles") {
    GameCourtView(
        seats: GameSeats(capacity: 2, players: 1, spotsLeft: 1, viewerIsBooker: true, viewerIsPlaying: false),
        court: .net, organiserName: "Иван", large: true
    )
    .padding()
}

#Preview("Team") {
    GameCourtView(
        seats: GameSeats(capacity: 14, players: 6, spotsLeft: 4, viewerIsBooker: false, viewerIsPlaying: true),
        court: .pitch, organiserName: nil
    ) {}
    .padding()
}
