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
                case .locating:
                    ProgressView(String(localized: "venues.locating"))
                case .locationDenied:
                    ContentUnavailableView(
                        String(localized: "venues.nearMe"),
                        systemImage: "location.slash",
                        description: Text(String(localized: "venues.noLocation"))
                    )
                case .loaded where model.rows.isEmpty:
                    ContentUnavailableView(
                        model.mode == .near
                            ? String(localized: "venues.noneNearby")
                            : String(localized: "venues.empty"),
                        systemImage: "figure.tennis"
                    )
                case .loaded:
                    List(model.rows) { row in
                        NavigationLink {
                            VenueDetailView(venueId: row.id, session: session)
                        } label: {
                            VenueRow(row: row)
                        }
                    }
                    .refreshable { await model.load(session) }
                }
            }
            .navigationTitle(String(localized: "venues.title"))
            .safeAreaInset(edge: .top) {
                Picker("", selection: .init(
                    get: { model.mode },
                    set: { newMode in Task { await model.setMode(newMode, session: session) } }
                )) {
                    Text(String(localized: "venues.all")).tag(VenueListModel.Mode.all)
                    Text(String(localized: "venues.nearMe")).tag(VenueListModel.Mode.near)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 4)
                .background(.bar)
            }
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
    let row: VenueListModel.Row

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.name).font(.headline)

            // A separate "·" Text is read as its own fragment by VoiceOver and
            // wraps badly at large sizes. One string instead.
            Text(placeLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let line = priceLine {
                Text(line).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        // One utterance per club. Left alone, VoiceOver reads three fragments
        // and the NavigationLink's own label on top of them.
        .accessibilityElement(children: .combine)
    }

    private var placeLine: String {
        let place = [row.city, row.country].joined(separator: ", ")
        guard let km = row.distanceKm else { return place }
        let distance = String(
            format: String(localized: "venues.distance"),
            km.formatted(.number.precision(.fractionLength(1)))
        )
        return "\(place) · \(distance)"
    }

    /// Nil in `near` mode — that endpoint carries no price, and inventing one
    /// is worse than omitting it.
    ///
    /// In `all` mode a null `fromPriceCents` means the club has no bookable
    /// court. NOT zero: the server's DTO comment is explicit that 0 would
    /// render as "free".
    private var priceLine: String? {
        guard row.distanceKm == nil else { return nil }
        guard let cents = row.fromPriceCents else {
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
    enum Phase { case loading, loaded, failed, locating, locationDenied }
    enum Mode { case all, near }

    /// A row either way, so the list does not need two branches.
    struct Row: Identifiable {
        let id: String
        let name: String
        let city: String
        let country: String
        let fromPriceCents: Int?
        /// Only present in `near` mode.
        let distanceKm: Double?
    }

    private(set) var phase: Phase = .loading
    private(set) var rows: [Row] = []
    private(set) var mode: Mode = .all

    private let location = LocationProvider()

    func setMode(_ mode: Mode, session: SessionModel) async {
        guard mode != self.mode || rows.isEmpty else { return }
        self.mode = mode
        await load(session)
    }

    func load(_ session: SessionModel) async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }

        do {
            switch mode {
            case .all:
                phase = .loading
                // Discovery is public — BearerMiddleware exempts it, so this
                // works signed out and does not widen what a browse correlates
                // with.
                let items = try await client.listVenues(.init()).ok.body.json.data.items
                rows = items.map {
                    Row(
                        id: $0.id, name: $0.name, city: $0.city, country: $0.country,
                        fromPriceCents: $0.fromPriceCents, distanceKm: nil
                    )
                }

            case .near:
                phase = .locating
                let here = try await location.current()

                phase = .loading
                let result = try await client.findVenuesNear(
                    .init(
                        query: .init(
                            lat: here.latitude,
                            lng: here.longitude,
                            // Named radiusKm, not radius, and silently clamped
                            // to 50 rather than rejected — so asking for more
                            // would quietly mean 50 anyway.
                            radiusKm: 50
                        )
                    )
                ).ok.body.json.data
                rows = result.venues.map {
                    Row(
                        id: $0.id, name: $0.name, city: $0.city, country: $0.country,
                        // /venues/near does not carry a price; the row omits it
                        // rather than showing a wrong one.
                        fromPriceCents: nil, distanceKm: $0.distanceKm
                    )
                }
            }
            phase = .loaded
        } catch LocationProvider.Failure.denied {
            // Recoverable only in Settings, so say which switch, not "error".
            phase = .locationDenied
        } catch {
            phase = .failed
        }
    }
}
