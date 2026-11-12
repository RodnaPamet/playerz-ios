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
                .brandListRow()
                Section {
                    ForEach(owed.texts) { text in
                        LegalTextRow(text: text, url: session.legalTextURL(text.id))
                    }
                }
                .brandListRow()
                Section {
                    Button(action: accept) {
                        HStack {
                            Text(
                                accepting
                                    ? String(localized: "onboarding.terms.continuing")
                                    : String(localized: "onboarding.terms.accept")
                            )
                            if accepting {
                                ProgressView().tint(Theme.Palette.onAccent)
                            }
                        }
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(accepting)
                    if let problem {
                        Text(problem)
                            .foregroundStyle(Theme.Palette.danger)
                            .accessibilityFocused($problemFocused)
                    }
                } footer: {
                    Text(String(localized: "onboarding.terms.decline"))
                }
                .listPillRow()
                Section {
                    Button(String(localized: "profile.title"), action: openProfile)
                        .buttonStyle(.brandSecondary)
                }
                .listPillRow()
            }
            .brandPage()
            // Hidden with the system bar; still what VoiceOver calls the screen.
            .navigationTitle(String(localized: "onboarding.terms.title"))
            // The band's title wraps, so «Условия и поверителност» is no longer cut.
            .brandHeader(.title(String(localized: "onboarding.terms.title")))
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
