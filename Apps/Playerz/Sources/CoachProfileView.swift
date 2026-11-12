import PlayerzAPI
import SwiftUI

/// «Профил на треньор» (playerz-ios#20), the web's `/me/coach`: where the
/// profile stands with the platform, the text and the sports a coach teaches,
/// the certificate (seen only by playerz's own team), and sending it for
/// approval or taking it back.
struct CoachProfileView: View {
    @Bindable var session: SessionModel

    @State private var model = CoachProfileModel()
    /// A DEBUG launch can open one of the coach's screens (DebugLaunch).
    @State private var debugArea: String?
    @State private var debugLinks = CoachLinksModel()

    var body: some View {
        Group {
            if let profile = model.profile {
                Form {
                    Group {
                        CoachProfileStateSection(profile: profile)
                        if let line = model.line {
                            Section {
                                Text(line.text)
                                    .foregroundStyle(line.isError ? Theme.Palette.danger : Theme.Palette.success)
                            }
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
                    }
                    .brandListRow()
                    if profile.canEdit.text {
                        Section {
                            Button(String(localized: "coachProfile.save"), action: save)
                                .buttonStyle(.brandPrimary)
                                .disabled(model.busy || !model.edited || tooLong)
                        }
                        .bareListRow()
                    }
                    CoachCertificateSection(profile: profile, model: model, session: session)
                        .brandListRow()
                    // Its own rows: a card for what is missing, the button on the page.
                    CoachProfileSubmitSection(profile: profile, model: model, session: session)
                    Group {
                        // Where they teach, their days off and their lessons (#21).
                        Section {
                            NavigationLink {
                                CoachVenuesView(session: session)
                            } label: {
                                Label(String(localized: "coachVenues.title"), systemImage: "sportscourt")
                            }
                            if profile.state == .APPROVED {
                                NavigationLink {
                                    CoachTimeOffView(session: session)
                                } label: {
                                    Label(String(localized: "coachVenues.timeOff.title"), systemImage: "sun.max")
                                }
                                NavigationLink {
                                    CoachLessonsView(session: session)
                                } label: {
                                    Label(String(localized: "coachLessons.title"), systemImage: "figure.tennis")
                                }
                            }
                        }
                    }
                    .brandListRow()
                }
                .refreshable { await model.load(session) }
            } else if model.failed {
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "profile.failed")) {
                    Button(String(localized: "venues.retry"), action: retry)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView(String(localized: "common.loading"))
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(String(localized: "coachProfile.title"))
        .brandHeader(.back(String(localized: "coachProfile.title")))
        .task {
            await model.load(session)
            if let area = DebugLaunch.coachArea {
                if area == "terms" { await debugLinks.load(session) }
                debugArea = area
            }
        }
        .navigationDestination(item: $debugArea) { area in
            switch area {
            case "terms":
                if let link = debugLinks.links.first(where: { $0.status == .ACTIVE }) {
                    CoachTermsView(link: link, model: debugLinks, session: session)
                }
            case "timeoff": CoachTimeOffView(session: session)
            case "lessons": CoachLessonsView(session: session)
            default: CoachVenuesView(session: session)
            }
        }
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
