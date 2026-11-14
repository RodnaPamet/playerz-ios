import PlayerzAPI
import SwiftUI

/// A booking or a game the assistant prepared, opened in the app's own
/// screens with the court and the hours already picked: the reservation
/// summary (`ReservationSheet`) for a booking, the players' step of «Нова
/// игра» (`NewGameDetailsView`) for a game. The person checks it and
/// confirms there, under every normal rule and price; nothing is booked
/// before that.
///
/// The club's hours are read first, and the draft's hours picked from them
/// as a tap on the grid would pick them. An hour taken since the answer is
/// said, with the club's page to choose another.
struct AssistantProposalFlow: View {
    let proposal: AssistantProposal
    @Bindable var session: SessionModel

    @State private var model = VenueDetailModel()
    @State private var phase: Phase = .loading
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case loading
        case ready
        /// The hours are no longer free, or the court is gone.
        case gone
        case failed
    }

    var body: some View {
        switch phase {
        case .ready where proposal.kind == .booking:
            ReservationSheet(model: model, session: session, venueId: proposal.venueId, venueName: venueName)
        case .ready:
            NavigationStack {
                NewGameDetailsView(
                    session: session, model: model, venueId: proposal.venueId, venueName: venueName,
                    sport: sport,
                    spots: min(max(proposal.spots ?? 1, 1), 7),
                    levelMin: proposal.levelMin, levelMax: proposal.levelMax
                )
            }
        case .loading:
            frame {
                ProgressView(String(localized: "common.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .task { await prepare() }
        case .gone:
            frame {
                BrandEmptyState(
                    systemImage: "calendar.badge.exclamationmark", title: AssistantText.gone, message: AssistantText.goneHint
                ) {
                    NavigationLink {
                        VenueDetailView(venueId: proposal.venueId, session: session)
                    } label: {
                        Text(AssistantText.openVenue)
                    }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                }
            }
        case .failed:
            frame {
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "venue.failed")) {
                    Button(String(localized: "venues.retry")) { Task { await prepare() } }
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            }
        }
    }

    private var venueName: String { model.venue?.name ?? "" }

    private var sport: String {
        model.courts.first { $0.resourceId == proposal.resourceId }?.sport ?? ""
    }

    /// The draft's day at the club, its court, and its hours picked.
    private func prepare() async {
        phase = .loading
        await model.load(session, venueId: proposal.venueId)
        guard model.phase == .loaded else {
            phase = .failed
            return
        }
        // The strip's day the draft starts on, in the club's own zone.
        if let day = model.days.last(where: { $0.start <= proposal.start }), day.apiDate != model.selectedDate {
            await model.select(session, venueId: proposal.venueId, day: day)
        }
        model.clearPicks()
        guard let court = model.courts.first(where: { $0.resourceId == proposal.resourceId }) else {
            phase = .gone
            return
        }
        let hours = court.bookable.filter { $0.startTs >= proposal.start && $0.endTs <= proposal.end }
        let covered = hours.reduce(0) { $0 + $1.endTs.timeIntervalSince($1.startTs) }
        // Every hour of it still free, or none is picked: half a booking is
        // not what the person was offered.
        guard !hours.isEmpty, covered >= proposal.end.timeIntervalSince(proposal.start) else {
            phase = .gone
            return
        }
        for hour in hours { model.toggle(court, hour) }
        phase = .ready
    }

    /// A title and a way out while there is nothing to confirm yet.
    private func frame(@ViewBuilder _ content: () -> some View) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Palette.page.ignoresSafeArea())
                .navigationTitle(AssistantText.open(proposal.kind))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.close")) { dismiss() }
                    }
                }
        }
    }
}
