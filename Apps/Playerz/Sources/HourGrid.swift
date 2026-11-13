import PlayerzAPI
import SwiftUI

/// A place's hours as a grid, grouped by part of the day (the design draft):
/// each cell its start time and price; a taken hour shown and labelled, not
/// left out; a picked one in the accent. Three to a row, fewer as the text
/// grows.
struct HourGrid: View {
    let court: VenueDetailModel.Court
    let timezone: String
    let isPicked: (Components.Schemas.AvailabilitySlot) -> Bool
    let toggle: (Components.Schemas.AvailabilitySlot) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var zone: TimeZone { TimeZone(identifier: timezone) ?? .current }

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 1 : typeSize >= .xxLarge ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(HourlySlots.dayparts(court.hours, timezone: zone), id: \.part) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(Self.title(group.part))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Theme.Spacing.xs)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.s) {
                        ForEach(group.slots, id: \.startTs) { slot in
                            HourCell(
                                slot: slot, currency: court.currency, zone: zone,
                                picked: isPicked(slot)
                            ) { toggle(slot) }
                        }
                    }
                }
            }
        }
        // Clear of the list section's rounded corners, which clip a row's
        // content: the first title lost half its letter there.
        .padding(.vertical, Theme.Spacing.m)
    }

    static func title(_ part: HourlySlots.Daypart) -> String {
        switch part {
        case .morning: String(localized: "hours.morning")
        case .afternoon: String(localized: "hours.afternoon")
        case .evening: String(localized: "hours.evening")
        }
    }
}

/// One hour: «17:00» and its price, or «Заето».
private struct HourCell: View {
    let slot: Components.Schemas.AvailabilitySlot
    let currency: String
    let zone: TimeZone
    let picked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 2) {
                Text(start)
                    .font(Theme.Typography.displayUpright(22, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(slot.available ? Color.primary : Color.secondary)
                Text(slot.available ? price : String(localized: "hours.taken"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(picked ? Theme.Palette.accentText : Color.secondary)
            }
            .padding(.horizontal, Theme.Spacing.s + 2)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(picked ? Theme.Palette.selectedFill : Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.chip))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .strokeBorder(picked ? Theme.Palette.accentText : Theme.Palette.hairline, lineWidth: picked ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if picked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.accentText)
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
            .opacity(slot.available ? 1 : 0.64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!slot.available)
        .accessibilityLabel(slot.available
            ? String(localized: "venue.hour.spoken \(hours) \(price)")
            : String(localized: "hours.taken.spoken \(hours)"))
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    private var style: Date.FormatStyle {
        Date.FormatStyle(timeZone: zone).hour(.twoDigits(amPM: .omitted)).minute()
    }

    private var start: String { slot.startTs.formatted(style) }
    private var hours: String { "\(slot.startTs.formatted(style)) – \(slot.endTs.formatted(style))" }
    private var price: String { (Decimal(slot.priceCents) / 100).formatted(.currency(code: currency)) }
}
