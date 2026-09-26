import SwiftUI

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
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await session.signIn(email: email, password: password) }
                    } label: {
                        if session.busy {
                            ProgressView()
                        } else {
                            Text(String(localized: "signIn.submit"))
                        }
                    }
                    .disabled(session.busy || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle(String(localized: "signIn.title"))
        }
    }
}
