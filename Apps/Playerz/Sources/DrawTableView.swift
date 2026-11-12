import PlayerzAPI
import SwiftUI

/// A group's table: place, entry, and played, won, drawn, lost and points,
/// with the full words for VoiceOver.
struct DrawTableView: View {
    let table: [Components.Schemas.Draw.groupsPayloadPayload.tablePayloadPayload]

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize { stacked } else { grid }
    }

    /// At the accessibility sizes six columns do not fit a phone (#72): each
    /// entry is its name, then its numbers as short-label pairs that wrap.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(table, id: \.entryId) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(row.rank). \(DrawText.entry(row.entry))")
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(row.entry.withdrawn)
                    Text(numbers(row))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(row))
            }
        }
    }

    private func numbers(_ row: Components.Schemas.Draw.groupsPayloadPayload.tablePayloadPayload) -> String {
        let columns = [("played", row.played), ("won", row.won), ("drawn", row.drawn), ("lost", row.lost), ("points", row.points)]
        return columns.map { "\(localized(key: "tournaments.draw.colShort.\($0.0)")) \($0.1.formatted())" }
            .joined(separator: " · ")
    }

    private var grid: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Text(String(localized: "tournaments.draw.entry"))
                ForEach(["played", "won", "drawn", "lost", "points"], id: \.self) { column in
                    Text(localized(key: "tournaments.draw.colShort.\(column)"))
                        .gridColumnAlignment(.trailing)
                }
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            ForEach(table, id: \.entryId) { row in
                GridRow {
                    Text("\(row.rank). \(DrawText.entry(row.entry))")
                        .strikethrough(row.entry.withdrawn)
                    // By position: two columns often hold the same number.
                    ForEach(Array([row.played, row.won, row.drawn, row.lost, row.points].enumerated()), id: \.offset) { _, number in
                        Text(number.formatted()).monospacedDigit()
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(row))
            }
        }
        .font(.subheadline)
    }

    private func label(_ row: Components.Schemas.Draw.groupsPayloadPayload.tablePayloadPayload) -> String {
        let columns = [("played", row.played), ("won", row.won), ("drawn", row.drawn), ("lost", row.lost), ("points", row.points)]
        let parts = columns.map { "\(localized(key: "tournaments.draw.col.\($0.0)")) \($0.1)" }
        return (["\(row.rank). \(DrawText.entry(row.entry))"] + parts).joined(separator: ", ")
    }
}
