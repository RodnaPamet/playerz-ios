import PlayerzAPI
import SwiftUI

/// The screen an `AppLink` names, for a notification or a tapped push
/// (playerz-ios#15). The tab links switch tabs instead (`SessionModel.open`).
struct LinkedScreen: View {
    let link: AppLink
    @Bindable var session: SessionModel

    var body: some View {
        switch link {
        case let .booking(id):
            BookingDetailView(bookingId: id, session: session)
        case let .conversation(id) where session.modules.messaging:
            ConversationView(conversationId: id, session: session)
        default:
            ContentUnavailableView(String(localized: "notifications.noScreen"), systemImage: "bell.slash")
        }
    }
}
