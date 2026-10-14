import SwiftUI

/// A conversation opened from outside the inbox («Пиши на клуба», «Пиши» to a
/// booking's player, a game's chat), shown in a sheet with its own stack so the
/// screen it was opened from keeps its place (#484).
struct OpenedConversation: Identifiable, Hashable {
    let id: String
}

struct ConversationSheet: View {
    let opened: OpenedConversation
    @Bindable var session: SessionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ConversationView(conversationId: opened.id, session: session)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "messages.close")) { dismiss() }
                    }
                }
        }
    }
}
