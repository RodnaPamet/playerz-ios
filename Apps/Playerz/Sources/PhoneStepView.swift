import PlayerzAPI
import SwiftUI

/// «Потвърдете телефонен номер» (playerz-ios#11): the web's `/start/phone`.
///
/// With the phone rule on (`Me.phone.required`), a booking, a join request and
/// a message need a number confirmed by an SMS code. `LandingGate` offers the
/// step once per account; a `PHONE_REQUIRED` refusal anywhere opens it again
/// over the screen. «Не сега» goes on without it, as on the web.
struct PhoneStepView: View {
    @Bindable var session: SessionModel
    /// The number is the account's now.
    let confirmed: () -> Void
    /// «Не сега».
    let later: () -> Void

    @State private var number = ""
    @State private var code = ""
    @State private var sent: PhoneCode?
    @State private var busy = false
    @State private var problem: String?
    @State private var note: String?
    @AccessibilityFocusState private var problemFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // The full title here, where it wraps: beside «Не сега» in the bar it is cut.
                    Text(String(localized: "phone.step.title"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(String(localized: "phone.step.description"))
                }
                if let sent {
                    Section {
                        TextField(String(localized: "phone.step.code.label"), text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        Button(String(localized: "phone.step.code.submit"), action: confirm)
                            .disabled(busy || code.isEmpty)
                        Button(String(localized: "phone.step.code.resend"), action: resend)
                            .disabled(busy)
                        Button(String(localized: "phone.step.code.change"), action: changeNumber)
                            .disabled(busy)
                    } header: {
                        Text(String(localized: "phone.step.code.sentTo \(sent.maskedNumber)"))
                    } footer: {
                        if let note { Text(note) }
                    }
                } else {
                    Section {
                        TextField(String(localized: "phone.step.number.placeholder"), text: $number)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                        Button(String(localized: "phone.step.number.submit"), action: send)
                            .disabled(busy || number.trimmingCharacters(in: .whitespaces).isEmpty)
                    } header: {
                        Text(String(localized: "phone.step.number.label"))
                    } footer: {
                        Text(String(localized: "phone.step.number.hint"))
                    }
                }
                if let problem {
                    Section {
                        Text(problem)
                            .foregroundStyle(.red)
                            .accessibilityFocused($problemFocused)
                    }
                }
                Section {
                    Text(String(localized: "phone.step.privacy"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(String(localized: "phone.step.number.label"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "phone.step.later"), action: later)
                        .disabled(busy)
                }
            }
        }
        .interactiveDismissDisabled(busy)
    }

    private func send() {
        busy = true
        Task { await request(resent: false) }
    }

    private func resend() {
        busy = true
        Task { await request(resent: true) }
    }

    private func request(resent: Bool) async {
        problem = nil
        note = nil
        defer { busy = false }
        do {
            sent = try await session.startPhone(number)
            code = ""
            if resent { note = String(localized: "phone.step.code.resent") }
        } catch {
            show(error)
        }
    }

    private func confirm() {
        guard let sent else { return }
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            do {
                try await session.confirmPhone(number, code: code, challenge: sent.challenge)
                confirmed()
            } catch {
                show(error)
            }
        }
    }

    private func changeNumber() {
        sent = nil
        code = ""
        problem = nil
        note = nil
    }

    private func show(_ error: Error) {
        problem = PhoneStepText.error(error as? PhoneStepError ?? .failed)
        problemFocused = true
    }
}
