import PlayerzAPI
import SwiftUI

/// «Създай»: what the bar's round button offers. A module the server has off
/// has no row (#16).
struct CreateSheet: View {
    enum Choice { case court, game, lesson }

    let modules: Modules
    let choose: (Choice) -> Void

    var body: some View {
        BrandDarkSheet(
            title: String(localized: "create.title"),
            subtitle: String(localized: "create.subtitle")
        ) {
            BrandSheetRow(
                title: String(localized: "create.court.title"),
                subtitle: String(localized: "create.court.subtitle"),
                systemImage: "calendar.badge.plus"
            ) { choose(.court) }
            if modules.openPlay {
                BrandSheetRow(
                    title: String(localized: "create.game.title"),
                    subtitle: String(localized: "create.game.subtitle"),
                    systemImage: "person.2.badge.plus"
                ) { choose(.game) }
            }
            if modules.coaches {
                BrandSheetRow(
                    title: String(localized: "create.lesson.title"),
                    subtitle: String(localized: "create.lesson.subtitle"),
                    systemImage: "figure.tennis"
                ) { choose(.lesson) }
            }
        }
    }
}

#Preview {
    CreateSheet(modules: .unknown) { _ in }
}
