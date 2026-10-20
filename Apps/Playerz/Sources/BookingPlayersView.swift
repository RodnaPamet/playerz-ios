import PlayerzAPI
import SwiftUI

/// The people on one of the caller's bookings (#358), with «Пиши» to each
/// other registered player (#484). Names only: the server never gives a user
/// id here, so a conversation is opened by the player's place on the booking.
///
/// What each side may do (playerz-ios#14), while `playersOpen` (the booking
/// holds its court and has not started): the booker invites players (people
/// they have played with, or a link to share) and removes added ones; an added
/// player leaves.
struct BookingPlayersView: View {
    let bookingId: String
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var standing: Components.Schemas.BookingParticipants?
    @State private var failed = false
    @State private var conversation: OpenedConversation?
    @State private var problem: String?
    @State private var inviting = false
    @State private var removing: Components.Schemas.BookingPlayer?
    @State private var confirmingRemove = false
    @State private var confirmingLeave = false
    @State private var busy = false

    var body: some View {
        List {
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            if let standing {
                Section {
                    ForEach(Array(standing.players.enumerated()), id: \.offset) { _, player in
                        BookingPlayerRow(
                            player: player,
                            name: name(player),
                            messaging: session.modules.messaging,
                            write: { write(player) }
                        )
                            .swipeActions {
                                if canRemove(player, standing) {
                                    Button(String(localized: "myBookings.players.remove"), role: .destructive) {
                                        askToRemove(player)
                                    }
                                }
                            }
                            .accessibilityActions {
                                if canRemove(player, standing) {
                                    Button(String(localized: "myBookings.players.removeLabel \(name(player))")) {
                                        askToRemove(player)
                                    }
                                }
                            }
                    }
                } footer: {
                    Text(footer(standing))
                }
                if standing.playersOpen, standing.viewerRole == .BOOKER, standing.spotsLeft > 0 {
                    Section {
                        Button(String(localized: "myBookings.players.invite"), systemImage: "person.badge.plus", action: invite)
                    }
                }
                if standing.playersOpen, standing.viewerRole == .PARTICIPANT {
                    Section {
                        Button(String(localized: "myBookings.players.leave"), role: .destructive, action: askToLeave)
                            .disabled(busy)
                            .confirmationDialog(
                                String(localized: "myBookings.players.leaveConfirm.title"),
                                isPresented: $confirmingLeave,
                                titleVisibility: .visible
                            ) {
                                Button(String(localized: "myBookings.players.leaveConfirm.yes"), role: .destructive, action: leave)
                            } message: {
                                Text(String(localized: "myBookings.players.leaveConfirm.description"))
                            }
                    }
                }
            } else if failed {
                Text(String(localized: "bookingPlayers.failed")).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "bookingPlayers.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $conversation) { opened in
            ConversationSheet(opened: opened, session: session)
        }
        .sheet(isPresented: $inviting, onDismiss: reload) {
            InvitePlayersView(
                bookingId: bookingId,
                spotsLeft: standing?.spotsLeft ?? 0,
                liveLinks: standing?.liveInviteLinks ?? 0,
                session: session
            )
        }
        .confirmationDialog(
            String(localized: "myBookings.players.removeConfirm.title \(removing.map(name) ?? "")"),
            isPresented: $confirmingRemove,
            titleVisibility: .visible,
            presenting: removing
        ) { player in
            Button(String(localized: "myBookings.players.removeConfirm.yes"), role: .destructive) {
                remove(player)
            }
        } message: { _ in
            Text(String(localized: "myBookings.players.removeConfirm.description"))
        }
    }

    private func name(_ player: Components.Schemas.BookingPlayer) -> String {
        if player.deleted { return String(localized: "messages.deletedUser") }
        if player.isYou { return String(localized: "bookingPlayers.you") }
        return player.name ?? String(localized: "messages.unnamed")
    }

    private func canRemove(_ player: Components.Schemas.BookingPlayer, _ standing: Components.Schemas.BookingParticipants) -> Bool {
        standing.playersOpen && standing.viewerRole == .BOOKER && player.participantId != nil && !player.isBooker
    }

    private func footer(_ standing: Components.Schemas.BookingParticipants) -> String {
        guard standing.playersOpen else { return String(localized: "myBookings.players.closed") }
        return String(localized: "myBookings.players.spotsLeft \(standing.spotsLeft)")
    }

    private func reload() {
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            standing = try await client
                .listBookingParticipants(path: .init(id: bookingId))
                .ok.body.json.data
            failed = false
        } catch {
            failed = standing == nil
        }
    }

    private func invite() {
        inviting = true
    }

    private func askToRemove(_ player: Components.Schemas.BookingPlayer) {
        removing = player
        confirmingRemove = true
    }

    private func askToLeave() {
        confirmingLeave = true
    }

    private func write(_ player: Components.Schemas.BookingPlayer) {
        Task {
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

    private func remove(_ player: Components.Schemas.BookingPlayer) {
        guard let participantId = player.participantId else { return }
        busy = true
        Task {
            defer { busy = false }
            problem = nil
            guard let client = await session.client() else { return }
            let response = try? await client.removeBookingParticipant(
                path: .init(id: bookingId, participantId: participantId)
            )
            if case .noContent = response {
                await load()
            } else {
                problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }

    private func leave() {
        busy = true
        Task {
            defer { busy = false }
            problem = nil
            guard let client = await session.client() else { return }
            let response = try? await client.leaveBooking(path: .init(id: bookingId))
            if case .noContent = response {
                // The booking is no longer the caller's: back to the list.
                dismiss()
            } else {
                problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }
}
