import PlayerzAPI
import SwiftUI

/// «Къде искате да преподавате?»: the public venue index, the list a player
/// searches, by name or city. Picking one asks its club.
struct CoachVenueSearchSheet: View {
    @Bindable var session: SessionModel
    let ask: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var venues: [Components.Schemas.VenueSummary] = []
    @State private var asking: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "coachVenues.search.description")).foregroundStyle(.secondary)
                }
                if venues.isEmpty {
                    Text(String(localized: "coachVenues.search.empty")).foregroundStyle(.secondary)
                }
                ForEach(venues, id: \.id) { venue in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(venue.name)
                            Text(venue.city).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(String(localized: "coachVenues.search.ask")) { ask(venue.id) }
                            .buttonStyle(.bordered)
                            .disabled(asking != nil)
                    }
                }
            }
            .searchable(text: $term, prompt: String(localized: "coachVenues.search.label"))
            .navigationTitle(String(localized: "coachVenues.search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "coachVenues.action.cancel"), action: close)
                }
            }
            .task(id: term) { await search() }
        }
    }

    private func close() {
        dismiss()
    }

    private func ask(_ venueId: String) {
        asking = venueId
        Task {
            defer { asking = nil }
            if await ask(venueId) { dismiss() }
        }
    }

    private func search() async {
        // A short pause, so typing does not send a request a letter.
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled, let client = await session.client() else { return }
        let query = Operations.listVenues.Input.Query(q: term.isEmpty ? nil : term, limit: 10)
        if let page = try? await client.listVenues(query: query).ok.body.json.data {
            venues = page.items
        }
    }
}
