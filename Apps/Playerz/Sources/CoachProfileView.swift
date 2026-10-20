import PlayerzAPI
import SwiftUI

/// «Профил на треньор» (playerz-ios#20), the web's `/me/coach`: where the
/// profile stands with the platform, the text and the sports a coach teaches,
/// the certificate (seen only by playerz's own team), and sending it for
/// approval or taking it back.
struct CoachProfileView: View {
    @Bindable var session: SessionModel

    @State private var model = CoachProfileModel()

    var body: some View {
        Group {
            if let profile = model.profile {
                Form {
                    CoachProfileStateSection(profile: profile)
                    if let line = model.line {
                        Section { Text(line.text).foregroundStyle(line.isError ? .red : .green) }
                    }
                    Section {
                        TextField(String(localized: "coachProfile.about.bio"), text: $model.bio, axis: .vertical)
                            .lineLimit(4...)
                            .disabled(!profile.canEdit.text)
                    } header: {
                        Text(String(localized: "coachProfile.about.title"))
                    } footer: {
                        Text(String(localized: "coachProfile.about.bioHint \(model.bio.count) \(CoachProfileModel.textMax)"))
                    }
                    Section {
                        TextField(String(localized: "coachProfile.about.qualifications"), text: $model.qualifications, axis: .vertical)
                            .lineLimit(2...)
                            .disabled(!profile.canEdit.text)
                    } footer: {
                        Text(String(localized: "coachProfile.about.qualificationsHint"))
                    }
                    CoachSportsSection(sports: $model.sports, editable: profile.canEdit.text)
                    if profile.canEdit.text {
                        Section {
                            Button(String(localized: "coachProfile.save"), action: save)
                                .disabled(model.busy || !model.edited || tooLong)
                        }
                    }
                    CoachCertificateSection(profile: profile, model: model, session: session)
                    CoachProfileSubmitSection(profile: profile, model: model, session: session)
                }
                .refreshable { await model.load(session) }
            } else if model.failed {
                ContentUnavailableView {
                    Text(String(localized: "profile.failed"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "coachProfile.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(session) }
    }

    private var tooLong: Bool {
        model.bio.count > CoachProfileModel.textMax || model.qualifications.count > CoachProfileModel.textMax
    }

    private func save() {
        Task { await model.save(session) }
    }

    private func retry() {
        Task { await model.load(session) }
    }
}
