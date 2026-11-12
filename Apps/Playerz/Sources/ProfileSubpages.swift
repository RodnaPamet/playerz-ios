import SwiftUI

/// «Класиране» from Профил (#18): each sport's level, the points and the
/// matches behind them, which only the player sees.
struct MyRatingsView: View {
    @Bindable var session: SessionModel

    var body: some View {
        Form {
            MyRatingsSection(session: session).brandListRow()
        }
        .brandPage()
        .navigationTitle(String(localized: "profile.ratings.title"))
        .brandHeader(.back(String(localized: "profile.ratings.title")))
    }
}

/// «Данни и изтриване на профила» from Профил (#9): downloading the data
/// and deleting the account, in the web's order.
struct AccountDataView: View {
    @Bindable var session: SessionModel

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                AccountDeletionSection(session: session).brandListRow()
            }
            .brandPage()
            .navigationTitle(String(localized: "profile.hub.data"))
            .brandHeader(.back(String(localized: "profile.hub.data")))
            .task {
                // A DEBUG launch lands on the delete button (DebugLaunch).
                guard DebugLaunch.profile == .delete || DebugLaunch.profile == .confirm else { return }
                // After the section has been laid out.
                try? await Task.sleep(for: .milliseconds(400))
                proxy.scrollTo(AccountDeletionSection.anchor, anchor: .bottom)
            }
        }
    }
}
