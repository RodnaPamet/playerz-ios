import PlayerzAPI
import SwiftUI

/// A group's table: place, entry, and played, won, drawn, lost and points,
/// with the full words for VoiceOver.
struct DrawTableView: View {
    let table: [Components.Schemas.Draw.groupsPayloadPayload.tablePayloadPayload]

    var body: some View {
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
