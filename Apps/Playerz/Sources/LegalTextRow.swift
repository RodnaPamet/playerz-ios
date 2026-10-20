import PlayerzAPI
import SwiftUI

/// One text owed: its name, opening it on the web, and the version in force.
struct LegalTextRow: View {
    let text: OwedTexts.Text
    let url: URL?

    var body: some View {
        LabeledContent {
            if let version = text.version {
                Text(String(localized: "onboarding.terms.version \(version)"))
            }
        } label: {
            if let url {
                Link(localized(key: "onboarding.terms.document.\(text.id)"), destination: url)
            } else {
                Text(localized(key: "onboarding.terms.document.\(text.id)"))
            }
        }
    }
}
