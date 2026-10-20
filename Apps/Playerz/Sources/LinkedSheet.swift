import PlayerzAPI
import SwiftUI

/// A tapped push's screen, over the tabs (playerz-ios#15).
struct LinkedSheet: View {
    let link: AppLink
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LinkedScreen(link: link, session: session)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.close"), action: close)
                    }
                }
        }
    }

    private func close() {
        dismiss()
    }
}
