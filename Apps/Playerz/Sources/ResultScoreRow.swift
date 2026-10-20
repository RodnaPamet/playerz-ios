import SwiftUI

/// One set (or the total): side 1's number, then side 2's.
struct ResultScoreRow: View {
    let label: String
    @Binding var first: String
    @Binding var second: String

    var body: some View {
        LabeledContent(label) {
            HStack {
                TextField(text: $first, prompt: Text(verbatim: "0")) {
                    Text(String(localized: "results.editor.cell \(label) \(1)"))
                }
                .frame(maxWidth: 56)
                TextField(text: $second, prompt: Text(verbatim: "0")) {
                    Text(String(localized: "results.editor.cell \(label) \(2)"))
                }
                .frame(maxWidth: 56)
            }
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
        }
    }
}
