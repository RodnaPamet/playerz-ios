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
        BrandDarkSheet(
            title: String(localized: "coachVenues.search.title"),
            subtitle: String(localized: "coachVenues.search.description")
        ) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityHidden(true)
                TextField(String(localized: "coachVenues.search.label"), text: $term)
                    .foregroundStyle(Theme.Palette.onHeader)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(Theme.Spacing.m)
            .frame(minHeight: Theme.minTarget)
            .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
            if venues.isEmpty {
                Text(String(localized: "coachVenues.search.empty"))
                    .foregroundStyle(.white.opacity(0.72))
            }
            ForEach(venues, id: \.id) { venue in
                VenueToAsk(venue: venue, busy: asking == venue.id, disabled: asking != nil) { ask(venue.id) }
            }
            Button(String(localized: "coachVenues.action.cancel"), action: close)
                .buttonStyle(.brandSecondary)
                .padding(.top, Theme.Spacing.s)
        }
        .task(id: term) { await search() }
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

/// A venue in the search: its name and city, and «Поискай» in the accent.
/// The button keeps the venue's name for VoiceOver, so ten of them are not
/// ten identical «Поискай».
private struct VenueToAsk: View {
    let venue: Components.Schemas.VenueSummary
    let busy: Bool
    let disabled: Bool
    let ask: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(venue.name)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(.white)
                Text(venue.city)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: Theme.Spacing.s)
            Button(action: ask) {
                Group {
                    if busy { ProgressView() } else { Text(String(localized: "coachVenues.search.ask")) }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Palette.onAccent)
                .padding(.horizontal, Theme.Spacing.l)
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                .background(Theme.Palette.accentFill, in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled && !busy ? 0.45 : 1)
            .accessibilityLabel(String(localized: "coachVenues.search.askAt \(venue.name)"))
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
    }
}
