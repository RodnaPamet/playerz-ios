import PlayerzAPI
import SwiftUI

/// The assistant's button, lower right on every signed-in screen, above the
/// floating bar (`PlayerShell` mounts it). Shown only while the server offers
/// the assistant (`SessionModel.showsAssistant`), which is asked again on
/// every return to the foreground, so it can go between one use and the next.
///
/// The conversation stays while the shell does: closing the sheet and opening
/// it again finds it where it was, until «Нов разговор».
struct AssistantLauncher: View {
    @Bindable var session: SessionModel
    /// The screen the question is asked from.
    let page: AssistantPage
    /// The button on show: offered by the server, and no keyboard up. Hidden
    /// rather than removed, so a sheet it opened stays open.
    let shown: Bool

    @State private var open = false
    @State private var store: AssistantStore?
    /// A draft chosen in the sheet, opened once the sheet has gone.
    @State private var pending: AssistantProposal?
    @State private var proposal: ProposalItem?

    var body: some View {
        Button {
            if store == nil { store = session.assistantStore() }
            open = true
        } label: {
            Label(AssistantText.title, systemImage: "sparkles")
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 52, height: 52)
                .background(Theme.Palette.actionFill, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                .themeShadow(.floating)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .accessibilityLabel(AssistantText.title)
        .accessibilityInputLabels([AssistantText.title, "Асистент", "Assistant"])
        .accessibilityShowsLargeContentViewer {
            Label(AssistantText.title, systemImage: "sparkles")
        }
        .sheet(isPresented: $open, onDismiss: {
            if let pending {
                proposal = ProposalItem(proposal: pending)
                self.pending = nil
            }
        }) {
            if let store {
                AssistantSheet(store: store, session: session, page: page) { draft in
                    pending = draft
                    open = false
                }
                .outsideShellBar()
            }
        }
        // The usual booking screen, filled: the person checks and confirms it.
        .sheet(item: $proposal) { item in
            AssistantProposalFlow(proposal: item.proposal, session: session)
                .outsideShellBar()
        }
    }
}

/// A draft on its way into the booking screen.
struct ProposalItem: Identifiable {
    let id = UUID()
    let proposal: AssistantProposal
}
