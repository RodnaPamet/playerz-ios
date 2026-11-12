import AuthenticationServices
import SwiftUI

/// Sign-in, in the restyle's look (owner 2026-11-12: the app's dark band and
/// the «playerz» wordmark, the fields on a card below, not a full-colour
/// splash).
///
/// «Вход с Google» whenever the build has the app's Google client (owner
/// 2026-11-13, for TestFlight); Apple still waits for the owner's go-ahead.
/// A Release build has its server built in, so the server field is a
/// development build's only; so is the password form once Google is offered,
/// because the server answers the password grant only in test runs (#361).
struct SignInView: View {
    @Bindable var session: SessionModel
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var email = ""
    @State private var password = ""

    private var isDevelopmentBuild: Bool { SessionModel.bundledServer == nil }

    var body: some View {
        NavigationStack {
            Form {
                if isDevelopmentBuild {
                    Section(String(localized: "signIn.server")) {
                        TextField("https://…", text: $session.serverURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }
                    .brandListRow()
                }

                if session.offersGoogle {
                    Section {
                        Button {
                            Task { await session.signInWithGoogle(using: webAuthenticationSession) }
                        } label: {
                            if session.busy {
                                ProgressView().tint(Theme.Palette.onAccent)
                            } else {
                                Text(String(localized: "signIn.google"))
                            }
                        }
                        .buttonStyle(.brandPrimary)
                        .disabled(session.busy)
                    } footer: {
                        if !showsPasswordForm, let error = session.signInError {
                            Text(error).foregroundStyle(Theme.Palette.danger)
                        }
                    }
                    .bareListRow()
                }

                if showsPasswordForm {
                    passwordForm
                }
            }
            .brandPage()
            // Hidden with the system bar; still what VoiceOver calls the screen.
            .navigationTitle(String(localized: "signIn.title"))
            .brandHeader(.wordmark)
        }
    }

    private var showsPasswordForm: Bool { isDevelopmentBuild || !session.offersGoogle }

    @ViewBuilder
    private var passwordForm: some View {
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
        .bareListRow()
    }
}
