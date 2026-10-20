import PlayerzAPI
import SwiftUI

/// A result as two lines, one a side: its players, then its score in each set
/// (or its one total), the winning side in bold, side 1 first as the server
/// stores it. A race (karting) is its finishing order instead.
struct ResultSummaryView: View {
    let sides: [[Components.Schemas.ResultPlayer]]
    let score: [[Int]]?
    let winnerSide: Int?
    let format: String

    var body: some View {
        if format == "ORDER" {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(sides.indices, id: \.self) { place in
                    Text(String(localized: "results.place \(place + 1) \(ResultText.side(sides[place]))"))
                        .bold(place == 0)
                }
            }
        } else {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                ForEach(sides.indices, id: \.self) { side in
                    GridRow {
                        Text(ResultText.side(sides[side]))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach((score ?? []).indices, id: \.self) { set in
                            Text(score?[set][safe: side].map(String.init) ?? "")
                                .monospacedDigit()
                                .gridColumnAlignment(.trailing)
                        }
                    }
                    .bold(winnerSide == side)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label(side))
                }
            }
        }
    }

    /// «Иван и Петър, победител: 6, 7».
    private func label(_ side: Int) -> String {
        let names = ResultText.side(sides[side])
        let points = (score ?? []).compactMap { $0[safe: side] }.map(String.init).joined(separator: ", ")
        let who = winnerSide == side ? "\(names), \(String(localized: "results.winner"))" : names
        return points.isEmpty ? who : "\(who): \(points)"
    }
}
