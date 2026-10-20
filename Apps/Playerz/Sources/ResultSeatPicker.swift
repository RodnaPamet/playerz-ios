import PlayerzAPI
import SwiftUI

/// One player's side: «Отбор 1», «Отбор 2» or «Не игра».
struct ResultSeatPicker: View {
    let name: String
    @Binding var seat: ResultDraft.Seat

    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
            Picker(String(localized: "results.editor.sideOf \(name)"), selection: $seat) {
                Text(String(localized: "results.editor.side \(1)")).tag(ResultDraft.Seat.side(0))
                Text(String(localized: "results.editor.side \(2)")).tag(ResultDraft.Seat.side(1))
                Text(String(localized: "results.editor.out")).tag(ResultDraft.Seat.out)
            }
            .pickerStyle(.segmented)
        }
    }
}
