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
            if model.loaded, !approved {
                Section { Text(String(localized: "coachVenues.needsApproval")).foregroundStyle(.secondary) }
            }
            if let line = model.line {
                Section { Text(line.text).foregroundStyle(line.isError ? .red : .green) }
            }
            if model.loaded, model.links.isEmpty {
                Section { Text(String(localized: "coachVenues.none")).foregroundStyle(.secondary) }
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
                    case .ACTIVE:
                        Button(String(localized: "coachVenues.action.end"), role: .destructive) { askToEnd(link) }
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
        .navigationTitle(String(localized: "coachVenues.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if approved {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "coachVenues.add"), systemImage: "plus", action: search)
                }
            }
        }
        .task { await model.load(session) }
        .refreshable { await model.load(session) }
        .sheet(isPresented: $searching) {
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
