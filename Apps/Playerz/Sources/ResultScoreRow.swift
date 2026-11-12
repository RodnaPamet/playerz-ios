import SwiftUI

/// One set (or the total): side 1's number, then side 2's.
struct ResultScoreRow: View {
    let label: String
    @Binding var first: String
    @Binding var second: String

    /// Two digits wide at any text size.
    @ScaledMetric(relativeTo: .body) private var cellWidth: CGFloat = 56

    var body: some View {
        LabeledContent(label) {
            HStack {
                TextField(text: $first, prompt: Text(verbatim: "0")) {
                    Text(String(localized: "results.editor.cell \(label) \(1)"))
                }
                .frame(maxWidth: cellWidth, minHeight: Theme.minTarget)
                TextField(text: $second, prompt: Text(verbatim: "0")) {
                    Text(String(localized: "results.editor.cell \(label) \(2)"))
                }
                .frame(maxWidth: cellWidth, minHeight: Theme.minTarget)
            }
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
        }
    }
}
