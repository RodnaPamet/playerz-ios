import SwiftUI

/// «Да изтрием ли профила ви?»: the button stays off until the word is typed.
struct ConfirmDeletionSheet: View {
    let delete: @MainActor () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "profile.delete.dialog.body"))
                    // The instruction is the field's name, so VoiceOver reads it
                    // with the field; the word is only the placeholder.
                    TextField(text: $typed, prompt: Text(String(localized: "profile.delete.dialog.word"))) {
                        Text(String(localized: "profile.delete.dialog.typeToConfirm \(String(localized: "profile.delete.dialog.word"))"))
                    }
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                } footer: {
                    Text(String(localized: "profile.delete.dialog.typeToConfirm \(String(localized: "profile.delete.dialog.word"))"))
                }
                .brandListRow()
                Section {
                    Button(role: .destructive, action: confirm) {
                        HStack {
                            Text(String(localized: "profile.delete.dialog.confirm"))
                                .font(.body.weight(.semibold))
                            if deleting {
                                Spacer()
                                ProgressView()
                            }
                        }
                        .foregroundStyle(Theme.Palette.danger)
                        // The colour is set by hand, so the off state has to be drawn too.
                        .opacity(DeletionWord.confirms(typed) && !deleting ? 1 : 0.4)
                        .frame(minHeight: Theme.minTarget)
                    }
                    .disabled(!DeletionWord.confirms(typed) || deleting)
                }
                .brandListRow()
            }
            .brandPage()
            // Hidden with the system bar; still what VoiceOver calls the screen.
            .navigationTitle(String(localized: "profile.delete.dialog.title"))
            .brandHeader(.title(String(localized: "profile.delete.dialog.title"))) {
                Button(String(localized: "profile.delete.dialog.cancel"), action: cancel)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.onHeader)
                    .frame(minHeight: Theme.minTarget)
                    .disabled(deleting)
            }
        }
        .interactiveDismissDisabled(deleting)
    }

    private func confirm() {
        // Before the Task: a second tap must find the button already off.
        deleting = true
        Task {
            await delete()
            deleting = false
            dismiss()
        }
    }

    private func cancel() {
        dismiss()
    }
}
