import SwiftUI

/// «Оспори»: why, for the club, if they want to say. A dark sheet, as the
/// other notes' sheets («Да поискаме ли място?»).
struct RejectResultSheet: View {
    let send: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    private static let maxLength = 500

    var body: some View {
        BrandDarkSheet(title: String(localized: "myBookings.result.reject")) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                TextField(String(localized: "myBookings.result.rejectNote"), text: $note, axis: .vertical)
                    .lineLimit(3...)
                    .foregroundStyle(Theme.Palette.onHeader)
                    .padding(Theme.Spacing.m)
                    .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
                // Over the limit: a warning sign as well as brighter text,
                // so the greyed button says why.
                HStack(spacing: Theme.Spacing.xs) {
                    if note.count > Self.maxLength {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    }
                    Text(String(localized: "games.noteHint \(Self.maxLength - note.count)"))
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(note.count > Self.maxLength ? 1 : 0.72))
            }
            Button(String(localized: "myBookings.result.rejectSend"), role: .destructive, action: submit)
                .buttonStyle(.brandPrimary)
                .disabled(note.count > Self.maxLength)
                .padding(.top, Theme.Spacing.s)
            Button(String(localized: "myBookings.result.back"), action: close)
                .buttonStyle(.brandSecondary)
        }
    }

    private func submit() {
        send(note)
    }

    private func close() {
        dismiss()
    }
}
