import PlayerzAPI
import SwiftUI

/// The people on one of the caller's bookings (#358), with «Пиши» to each
/// other registered player (#484). Names only: the server never gives a user
/// id here, so a conversation is opened by the player's place on the booking.
struct BookingPlayersView: View {
    let bookingId: String
    @Bindable var session: SessionModel

    @State private var players: [Components.Schemas.BookingPlayer] = []
    @State private var failed = false
    @State private var loaded = false
    @State private var conversation: OpenedConversation?
    @State private var problem: String?

    var body: some View {
        List {
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            if failed {
                Text(String(localized: "bookingPlayers.failed")).foregroundStyle(.red)
            } else if !loaded {
                ProgressView()
            }
            ForEach(Array(players.enumerated()), id: \.offset) { _, player in
                HStack {
                    VStack(alignment: .leading) {
                        Text(name(player))
                        if player.isBooker {
                            Text(String(localized: "bookingPlayers.booker"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !player.isYou && player.registered && !player.deleted {
                        Button(String(localized: "messages.write")) {
                            Task { await write(player) }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(String(localized: "a11y.writeTo \(name(player))"))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "bookingPlayers.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $conversation) { opened in
            ConversationSheet(opened: opened, session: session)
        }
    }

    private func name(_ player: Components.Schemas.BookingPlayer) -> String {
        if player.deleted { return String(localized: "messages.deletedUser") }
        if player.isYou { return String(localized: "bookingPlayers.you") }
        return player.name ?? String(localized: "messages.unnamed")
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            players = try await client
                .listBookingParticipants(path: .init(id: bookingId))
                .ok.body.json.data.players
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }

    private func write(_ player: Components.Schemas.BookingPlayer) async {
        problem = nil
        let request = Components.Schemas.OpenConversationRequest.case3(
            .init(bookingId: bookingId, participantId: player.participantId)
        )
        switch await ConversationOpener.open(session, request) {
        case .success(let id): conversation = OpenedConversation(id: id)
        case .failure(let failure): problem = failure.text
        }
    }
}
