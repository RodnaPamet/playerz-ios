import SwiftUI

/// Sign-in, in the restyle's look (owner 2026-11-12: the app's dark band and
/// the «playerz» wordmark, the fields on a card below, not a full-colour
/// splash). Password sign-in is what a test server offers; Google and Apple
/// wait for the owner's go-ahead.
struct SignInView: View {
    @Bindable var session: SessionModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "signIn.server")) {
                    TextField("https://…", text: $session.serverURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                .brandListRow()

                Section {
                    TextField(String(localized: "signIn.email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocorrectionDisabled()

                    SecureField(String(localized: "signIn.password"), text: $password)
                        .textContentType(.password)
                } footer: {
                    if let error = session.signInError {
                        Text(error).foregroundStyle(Theme.Palette.danger)
                    }
                }
                .brandListRow()

                Section {
                    Button {
                        Task { await session.signIn(email: email, password: password) }
                    } label: {
                        if session.busy {
                            ProgressView().tint(Theme.Palette.onAccent)
                        } else {
                            Text(String(localized: "signIn.submit"))
                        }
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(session.busy || email.isEmpty || password.isEmpty)
                }
                .listPillRow()
            }
            .brandPage()
            // Hidden with the system bar; still what VoiceOver calls the screen.
            .navigationTitle(String(localized: "signIn.title"))
            .brandHeader(.wordmark)
        }
    }
}
