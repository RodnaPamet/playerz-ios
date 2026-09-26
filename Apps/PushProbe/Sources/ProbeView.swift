import SwiftUI

struct ProbeView: View {
    @Bindable var model: ProbeModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("https://…", text: $model.serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("email", text: $model.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField("password", text: $model.password)
                }

                Section("1 — Apple") {
                    Button("Request a device token") {
                        Task { await model.requestToken() }
                    }
                    .disabled(model.busy)

                    if let t = model.deviceToken {
                        Text(t)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("2 — playerz.bg") {
                    Button("Sign in and register the device") {
                        Task { await model.signInAndRegister() }
                    }
                    .disabled(model.busy || model.deviceToken == nil)
                }

                Section("Log") {
                    ForEach(Array(model.log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Push Probe")
        }
    }
}
