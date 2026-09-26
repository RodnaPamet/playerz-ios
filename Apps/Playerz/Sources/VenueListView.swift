import PlayerzAPI
import SwiftUI

struct VenueListView: View {
    @Bindable var session: SessionModel
    @State private var model = VenueListModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .loading:
                    ProgressView(String(localized: "common.loading"))
                case .failed:
                    ContentUnavailableView {
                        Text(String(localized: "venues.failed"))
                    } actions: {
                        Button(String(localized: "venues.retry")) {
                            Task { await model.load(session) }
                        }
                    }
                case .loaded where model.venues.isEmpty:
                    ContentUnavailableView(String(localized: "venues.empty"), systemImage: "figure.tennis")
                case .loaded:
                    List(model.venues, id: \.id) { venue in
                        NavigationLink {
                            VenueDetailView(venueId: venue.id, session: session)
                        } label: {
                            VenueRow(venue: venue)
                        }
                    }
                    .refreshable { await model.load(session) }
                }
            }
            .navigationTitle(String(localized: "venues.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.signOut")) {
                        Task { await session.signOut() }
                    }
                }
            }
        }
        .task { await model.load(session) }
    }
}

private struct VenueRow: View {
    let venue: Components.Schemas.VenueSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(venue.name).font(.headline)
            Text([venue.city, venue.country].joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(priceLine).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// `fromPriceCents` is null when a club has no bookable court — NOT zero.
    /// The DTO comment on the server is explicit that 0 would render as "free".
    private var priceLine: String {
        guard let cents = venue.fromPriceCents else {
            return String(localized: "venues.noPrice")
        }
        let money = Decimal(cents) / 100
        let formatted = money.formatted(.currency(code: "EUR").locale(Locale(identifier: "bg_BG")))
        return String(format: String(localized: "venues.fromPrice"), formatted)
    }
}

@MainActor
@Observable
final class VenueListModel {
    enum Phase { case loading, loaded, failed }

    private(set) var phase: Phase = .loading
    private(set) var venues: [Components.Schemas.VenueSummary] = []

    func load(_ session: SessionModel) async {
        phase = .loading
        guard let client = await session.client() else {
            phase = .failed
            return
        }

        do {
            // Discovery is public — BearerMiddleware exempts it, so this works
            // signed out too and does not widen what a browse correlates with.
            let response = try await client.listVenues(.init())
            venues = try response.ok.body.json.data.items
            phase = .loaded
        } catch {
            phase = .failed
        }
    }
}
