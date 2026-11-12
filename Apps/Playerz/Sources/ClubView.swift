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
    /// The name is on the cover card; the header carries it only once the card is scrolled away (#55).
    @State private var heroShown = true
    /// The club's tournaments (#22), while the ranking module is on.
    @State private var tournaments: [Components.Schemas.Tournament] = []
    /// A DEBUG launch can open the club's «Класиране» at once (DebugLaunch).
    @State private var debugLeaderboard = DebugLaunch.clubLeaderboard

    var body: some View {
        Group {
            if let club {
                List {
                    Section {
                        ClubHero(club: club, serverURL: session.serverURL)
                            .onAppear { heroShown = true }
                            .onDisappear { heroShown = false }
                    }
                    // The card is its own surface: no row box around it.
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    Group {
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
                                BrandEmptyState(
                                    systemImage: "sportscourt",
                                    title: String(localized: "club.noVenues.title"),
                                    message: String(localized: "club.noVenues.description")
                                )
                                .inline()
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
                    .brandListRow()
                }
            } else if failed {
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "club.failed")) {
                    Button(String(localized: "venues.retry"), action: retry)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView()
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(club?.name ?? "")
        .brandHeader(.back(heroShown ? "" : club?.name ?? ""))
        .navigationDestination(isPresented: $debugLeaderboard) {
            ClubLeaderboardView(slug: slug, session: session)
        }
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

/// The top of a club's page: its cover and logo when the club has uploaded
/// them (else the drawn band and its initial), its name, what it says of itself.
private struct ClubHero: View {
    let club: Components.Schemas.ClubPublic
    let serverURL: String

    var body: some View {
        BrandCoverCard(coverHeight: 170, coverLabel: club.cover?.alt) {
            VenueCover(photo: club.cover, seed: club.id, serverURL: serverURL, pixelWidth: 1280)
        } logo: {
            VenueLogoTile(name: club.name, logoURL: club.logoUrl.flatMap { mediaURL($0, serverURL: serverURL) })
        } content: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(club.name)
                    .font(Theme.Typography.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                if let description = club.description, !description.isEmpty {
                    // The club's own line breaks are kept (#530).
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
