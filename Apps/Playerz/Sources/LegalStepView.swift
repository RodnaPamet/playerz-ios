import PlayerzAPI
import SwiftUI

/// «Условия и поверителност» (playerz-ios#10): new texts to accept before
/// anything else, as the web's `/start/terms`.
///
/// Shown by `LandingGate` while `GET /me/legal-acceptance` says something is
/// owed. Each text opens on the web, where it is published. Профил stays
/// reachable from here: a person who will not accept can still download their
/// data and delete the account, as on the web.
struct LegalStepView: View {
    @Bindable var session: SessionModel
    let owed: OwedTexts
    /// What is owed after accepting: nothing, so the gate moves on.
    let accepted: (OwedTexts) -> Void

    @State private var accepting = false
    @State private var problem: String?
    @State private var showingProfile = false
    @AccessibilityFocusState private var problemFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "onboarding.terms.description"))
                }
                Section {
                    ForEach(owed.texts) { text in
                        LegalTextRow(text: text, url: session.legalTextURL(text.id))
                    }
                }
                Section {
                    Button(action: accept) {
                        HStack {
                            Text(
                                accepting
                                    ? String(localized: "onboarding.terms.continuing")
                                    : String(localized: "onboarding.terms.accept")
                            )
                            if accepting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(accepting)
                    if let problem {
                        Text(problem)
                            .foregroundStyle(.red)
                            .accessibilityFocused($problemFocused)
                    }
                } footer: {
                    Text(String(localized: "onboarding.terms.decline"))
                }
                Section {
                    Button(String(localized: "profile.title"), action: openProfile)
                }
            }
            .navigationTitle(String(localized: "onboarding.terms.title"))
            // Inline: a large title cannot wrap, and «Условия и поверителност» is cut.
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingProfile) {
                ProfileView(session: session)
            }
        }
    }

    private func accept() {
        // Before the Task: a second tap must find the button already off.
        accepting = true
        problem = nil
        Task {
            defer { accepting = false }
            do {
                accepted(try await session.acceptTexts())
            } catch LegalStepError.rateLimited {
                problem = String(localized: "profile.delete.error.RATE_LIMITED")
                problemFocused = true
            } catch {
                problem = String(localized: "onboarding.terms.error")
                problemFocused = true
            }
        }
    }

    private func openProfile() {
        showingProfile = true
    }
}
