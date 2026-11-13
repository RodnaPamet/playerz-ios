import PlayerzAPI
import SwiftUI

/// The venue's courts drawn side by side, to choose one (owner 2026-11-13:
/// "a schematic way to choose a court graphically; the list of times only for
/// the court chosen"). Where the club has drawn a plan (#25) the plan does
/// this; here every venue has one. Each tile: the court as its sport's own
/// surface (SportPitch),
/// its name, indoor or outdoor, and how many times are free that day; a court
/// with none is dimmed, and the chosen one carries the accent and a tick.
struct VenueCourtPicker: View {
    let courts: [VenueDetailModel.Court]
    @Binding var selected: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Three across for a big club, two for a small one, one at the
    /// accessibility sizes, where a name needs the width.
    private var columnCount: Int {
        typeSize.isAccessibilitySize ? 1 : courts.count >= 5 ? 3 : 2
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.m, alignment: .top), count: columnCount),
            spacing: Theme.Spacing.m
        ) {
            ForEach(courts, id: \.resourceId) { tile($0) }
        }
    }

    private func tile(_ court: VenueDetailModel.Court) -> some View {
        let isSelected = selected == court.resourceId
        let free = court.bookable.count
        return Button {
            selected = court.resourceId
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SportPitchView(sport: court.sport)
                    .frame(height: columnCount == 3 ? 52 : 64)
                    .opacity(free == 0 ? 0.35 : 1)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.Palette.onHeader, Theme.Palette.accentFill)
                                .padding(4)
                                .accessibilityHidden(true)
                        }
                    }
                Text(court.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PlaceText.roof(PlaceWord.of(court.sport), indoor: court.isIndoor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(free == 0 ? String(localized: "venue.court.none") : String(localized: "venue.court.free \(free)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(free == 0 ? Color.secondary : Theme.Palette.success)
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.tile + 4))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.tile + 4)
                    .strokeBorder(isSelected ? Theme.Palette.accentFill : Theme.Palette.hairline, lineWidth: isSelected ? 2.5 : 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The court to show first: the one chosen while it is still there, else
    /// the first with a free time, else the first.
    static func initial(_ courts: [VenueDetailModel.Court], keeping current: String?) -> String? {
        if let current, courts.contains(where: { $0.resourceId == current }) { return current }
        return (courts.first { !$0.bookable.isEmpty } ?? courts.first)?.resourceId
    }
}
