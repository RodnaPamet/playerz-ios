import PlayerzAPI
import SwiftUI

/// Sending the profile for approval, with what it still lacks; or, while it
/// waits, taking it back to change it.
struct CoachProfileSubmitSection: View {
    let profile: Components.Schemas.MyCoachProfile
    let model: CoachProfileModel
    @Bindable var session: SessionModel

    var body: some View {
        switch profile.state {
        case .NONE, .DRAFT, .DECLINED:
            Section {
                if !profile.missing.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "coachProfile.missing.title")).font(.subheadline)
                        ForEach(profile.missing, id: \.self) { missing in
                            Text("• \(text(missing))").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                Button(String(localized: "coachProfile.submit"), action: submit)
                    .disabled(model.busy || !profile.missing.isEmpty)
            }
        case .SUBMITTED:
            Section {
                Button(String(localized: "coachProfile.withdraw"), action: withdraw)
                    .disabled(model.busy)
            }
        default:
            EmptyView()
        }
    }

    private func text(_ missing: Components.Schemas.MyCoachProfile.missingPayloadPayload) -> String {
        switch missing {
        case .bio: String(localized: "coachProfile.missing.bio \(CoachProfileModel.bioMin)")
        case .sports: String(localized: "coachProfile.missing.sports")
        case .certificate: String(localized: "coachProfile.missing.certificate")
        }
    }

    private func submit() {
        Task { await model.submit(session) }
    }

    private func withdraw() {
        Task { await model.withdraw(session) }
    }
}
