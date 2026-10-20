import PlayerzAPI
import SwiftUI

/// Where the profile stands: not sent, waiting, approved or declined, with the
/// platform's note on a decline.
struct CoachProfileStateSection: View {
    let profile: Components.Schemas.MyCoachProfile

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(key: "coachProfile.state.\(profile.state.rawValue).title")).font(.headline)
                Text(summary(profile)).foregroundStyle(.secondary)
            }
            if profile.state == .DECLINED, let note = profile.decisionNote, !note.isEmpty {
                LabeledContent(String(localized: "coachProfile.note"), value: note)
            }
        } footer: {
            if profile.state == .NONE || profile.state == .DRAFT {
                Text(String(localized: "coachProfile.intro"))
            }
        }
    }

    private func summary(_ profile: Components.Schemas.MyCoachProfile) -> String {
        if profile.state == .SUBMITTED, let at = profile.submittedAt {
            return String(localized: "coachProfile.state.SUBMITTED.body \(at.formatted(date: .long, time: .omitted))")
        }
        return localized(key: "coachProfile.state.\(profile.state.rawValue).body")
    }
}
