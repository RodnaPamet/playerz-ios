import SwiftUI

/// A conversation opened from outside the inbox («Пиши на клуба», «Пиши» to a
/// booking's player, a game's chat), shown in a sheet with its own stack so the
/// screen it was opened from keeps its place (#484).
struct OpenedConversation: Identifiable, Hashable {
    let id: String
}

/// The conversation's header band closes the sheet: its back button
/// dismisses a stack's first screen, so no «Затвори» of its own.
struct ConversationSheet: View {
    let opened: OpenedConversation
    @Bindable var session: SessionModel

    var body: some View {
        NavigationStack {
            ConversationView(conversationId: opened.id, session: session)
        }
    }
}
