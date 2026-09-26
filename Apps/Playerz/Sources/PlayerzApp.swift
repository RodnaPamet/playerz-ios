import PlayerzAPI
import SwiftUI

@main
struct PlayerzApp: App {
    @State private var session = SessionModel()

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .task { await session.restore() }
        }
    }
}

/// Which screen the app is on, derived from whether a session exists.
///
/// Deliberately not a navigation stack decision: signing out must return to the
/// sign-in screen from anywhere, and a stack makes that a pop from an unknown
/// depth. Root swaps instead.
struct RootView: View {
    @Bindable var session: SessionModel

    var body: some View {
        switch session.state {
        case .unknown:
            ProgressView().controlSize(.large)
        case .signedOut:
            SignInView(session: session)
        case .signedIn:
            VenueListView(session: session)
        }
    }
}
