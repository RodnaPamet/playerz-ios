import PlayerzAPI
import SwiftUI

/// A club's public page (playerz-ios#17), the web's `/clubs/{slug}`: what the
/// club says about itself, its phone, and its venues, each opening its own
/// screen. From `GET /clubs/{slug}`, public.
struct ClubView: View {
    let slug: String
    @Bindable var session: SessionModel

    @State private var club: Components.Schemas.ClubPublic?
    @State private var failed = false
    /// The club's tournaments (#22), while the ranking module is on.
    @State private var tournaments: [Components.Schemas.Tournament] = []

    var body: some View {
        Group {
            if let club {
                List {
                    if let description = club.description, !description.isEmpty {
                        Section { Text(description) }
                    }
                    if let phone = club.phone, let call = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                        Section(String(localized: "club.contactLabel")) {
                            Link(String(localized: "club.phone \(phone)"), destination: call)
                        }
                    }
                    // «Класиране» (#18), while the ranking module is on.
                    if session.modules.ranking {
                        Section {
                            NavigationLink(String(localized: "club.leaderboard.title")) {
                                ClubLeaderboardView(slug: slug, session: session)
                            }
                        }
                    }
                    if session.modules.ranking, !tournaments.isEmpty {
                        Section(String(localized: "games.tab.tournaments")) {
                            ForEach(tournaments, id: \.id) { tournament in
                                NavigationLink {
                                    TournamentDetailView(id: tournament.id, session: session)
                                } label: {
                                    TournamentRow(tournament: tournament, entry: nil)
                                }
                            }
                        }
                    }
                    Section {
                        if club.venues.isEmpty {
                            ContentUnavailableView(
                                String(localized: "club.noVenues.title"),
                                systemImage: "sportscourt",
                                description: Text(String(localized: "club.noVenues.description"))
                            )
                        }
                        ForEach(club.venues, id: \.id) { venue in
                            NavigationLink {
                                VenueDetailView(venueId: venue.id, session: session)
                            } label: {
                                ClubVenueRow(venue: venue)
                            }
                        }
                    } header: {
                        Text(String(localized: "club.venuesTitle"))
                    } footer: {
                        Text(String(localized: "club.venuesCount \(club.venues.count)"))
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "club.failed"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(club?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func retry() {
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            club = try await client.getClub(.init(path: .init(slug: slug))).ok.body.json.data
            failed = false
        } catch {
            failed = club == nil
        }
        if session.modules.ranking,
           let listed = try? await client.listClubPublicTournaments(path: .init(slug: slug)).ok.body.json.data.items {
            tournaments = listed
        }
    }
}
