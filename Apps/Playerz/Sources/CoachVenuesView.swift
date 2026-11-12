import PlayerzAPI
import SwiftUI

/// «Клубове» (playerz-ios#21): the venues a coach teaches at or asked to, with
/// where each stands; asking a new one, withdrawing a request, stopping, and
/// each venue's terms and hours. Asking needs an approved profile.
struct CoachVenuesView: View {
    @Bindable var session: SessionModel

    @State private var model = CoachLinksModel()
    @State private var searching = false
    @State private var ending: Components.Schemas.MyCoachLink?
    @State private var confirmingEnd = false

    var body: some View {
        List {
            Group {
                if model.loaded, !approved {
                    Section { Text(String(localized: "coachVenues.needsApproval")).foregroundStyle(.secondary) }
                }
                if let line = model.line {
                    Section {
                        Text(line.text).foregroundStyle(line.isError ? Theme.Palette.danger : Theme.Palette.success)
                    }
                }
                ForEach(model.links, id: \.id) { link in
                    Section {
                        CoachLinkRow(link: link)
                        if link.status == .ACTIVE || link.status == .INVITED {
                            NavigationLink(String(localized: "coachVenues.action.terms")) {
                                CoachTermsView(link: link, model: model, session: session)
                            }
                        }
                        switch link.status {
                        case .REQUESTED:
                            Button(String(localized: "coachVenues.action.withdraw"), role: .destructive) { askToEnd(link) }
                                .foregroundStyle(Theme.Palette.danger)
                        case .ACTIVE:
                            Button(String(localized: "coachVenues.action.end"), role: .destructive) { askToEnd(link) }
                                .foregroundStyle(Theme.Palette.danger)
                        case .DECLINED, .ENDED:
                            if approved {
                                Button(String(localized: "coachVenues.action.again")) { askAgain(link) }
                            }
                        case .INVITED:
                            EmptyView()
                        }
                    }
                }
            }
            .brandListRow()
            if model.loaded, model.links.isEmpty {
                Section {
                    BrandEmptyState(systemImage: "sportscourt", title: String(localized: "coachVenues.none")) {
                        if approved {
                            Button(String(localized: "coachVenues.add"), action: search)
                                .buttonStyle(.brandPrimary(fullWidth: false))
                        }
                    }
                    .inline()
                }
                .bareListRow()
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(String(localized: "coachVenues.title"))
        .brandHeader(.back(String(localized: "coachVenues.title"))) {
            if approved {
                BrandHeaderButton(systemImage: "plus", label: String(localized: "coachVenues.add"), action: search)
            }
        }
        .task { await model.load(session) }
        .refreshable { await model.load(session) }
        .brandSheet(isPresented: $searching, detents: [.large]) {
            CoachVenueSearchSheet(session: session) { venueId in
                await model.request(venueId, session)
            }
        }
        .confirmationDialog(
            String(localized: "coachVenues.end.title \(endingName)"),
            isPresented: $confirmingEnd,
            titleVisibility: .visible,
            presenting: ending
        ) { link in
            Button(endLabel(link), role: .destructive) { end(link) }
        } message: { link in
            if link.status == .ACTIVE { Text(String(localized: "coachVenues.end.confirm")) }
        }
    }

    private var approved: Bool { model.approved }

    private var endingName: String { ending?.venue.name ?? "" }

    private func endLabel(_ link: Components.Schemas.MyCoachLink) -> String {
        link.status == .ACTIVE ? String(localized: "coachVenues.action.end") : String(localized: "coachVenues.action.withdraw")
    }

    private func search() {
        searching = true
    }

    private func askToEnd(_ link: Components.Schemas.MyCoachLink) {
        ending = link
        confirmingEnd = true
    }

    private func end(_ link: Components.Schemas.MyCoachLink) {
        Task { await model.end(link, session) }
    }

    private func askAgain(_ link: Components.Schemas.MyCoachLink) {
        Task { _ = await model.request(link.venue.id, session) }
    }
}
