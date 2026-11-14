import PlayerzAPI
import SwiftUI

/// One past conversation, opened from «Минали разговори»: read, and continued
/// from where it stopped, in the assistant's own sheet.
///
/// The turns are read first (`GET /me/assistant-conversations/{id}`), then
/// handed to a store of the sheet's own, so the next question carries this
/// conversation's id and the assistant answers it as a follow-up. Nothing of
/// it is cached: it is what the person said, as personal as messaging.
struct PastConversationSheet: View {
    let conversation: AssistantMemory.Conversation
    @Bindable var session: SessionModel
    /// A draft chosen in the sheet, for the screen behind it to open.
    var open: (AssistantProposal) -> Void = { _ in }

    @State private var store: AssistantStore?
    @State private var problem: AssistantMemoryError?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let store {
            AssistantSheet(store: store, session: session, page: nil, open: open)
        } else {
            NavigationStack {
                Group {
                    if let problem {
                        BrandEmptyState(systemImage: "wifi.exclamationmark", title: AssistantMemoryText.problem(problem)) {
                            Button(AssistantMemoryText.retry) { Task { await load() } }
                                .buttonStyle(.brandSecondary(fullWidth: false))
                        }
                    } else {
                        ProgressView(String(localized: "common.loading"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .task { await load() }
                    }
                }
                .background(Theme.Palette.page.ignoresSafeArea())
                .navigationTitle(AssistantText.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.close")) { dismiss() }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func load() async {
        problem = nil
        do {
            guard let client = await session.client() else { throw AssistantMemoryError.signedOut }
            let transcript = try await AssistantAPI.conversation(conversation.id, client: client)
            let fresh = session.assistantStore()
            fresh.resume(transcript)
            store = fresh
        } catch {
            problem = (error as? AssistantMemoryError) ?? .failed
        }
    }
}
