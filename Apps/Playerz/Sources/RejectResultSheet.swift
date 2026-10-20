import SwiftUI

/// «Оспори»: why, for the club, if they want to say.
struct RejectResultSheet: View {
    let send: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    private static let maxLength = 500

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "myBookings.result.rejectNote"), text: $note, axis: .vertical)
                        .lineLimit(3...)
                }
                Section {
                    Button(String(localized: "myBookings.result.rejectSend"), role: .destructive, action: submit)
                        .disabled(note.count > Self.maxLength)
                }
            }
            .navigationTitle(String(localized: "myBookings.result.reject"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "myBookings.result.back"), action: close)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() {
        send(note)
    }

    private func close() {
        dismiss()
    }
}
