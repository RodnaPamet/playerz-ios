import PlayerzAPI
import SwiftUI

/// «Покани играчи» (playerz-ios#14), the web's invite sheet: add people the
/// booker has played with, or share a link that adds whoever opens it and
/// signs in, while the court has room and until the start. Payment stays at
/// the club.
struct InvitePlayersView: View {
    let bookingId: String
    let spotsLeft: Int
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var coPlayers: [Components.Schemas.CoPlayer] = []
    @State private var loaded = false
    @State private var adding: String?
    @State private var added: Set<String> = []
    @State private var link: URL?
    @State private var liveLinks: Int
    @State private var linksStopped = false
    @State private var busy = false
    @State private var problem: String?

    init(bookingId: String, spotsLeft: Int, liveLinks: Int, session: SessionModel) {
        self.bookingId = bookingId
        self.spotsLeft = spotsLeft
        self.session = session
        _liveLinks = State(initialValue: liveLinks)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "myBookings.players.sheetDescription \(spotsLeft)"))
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
                Section(String(localized: "myBookings.players.recent")) {
                    if loaded, coPlayers.isEmpty {
                        Text(String(localized: "myBookings.players.recentEmpty")).foregroundStyle(.secondary)
                    } else if !loaded {
                        ProgressView()
                    }
                    ForEach(coPlayers, id: \.userId) { player in
                        HStack {
                            Text(player.name ?? String(localized: "messages.unnamed"))
                            Spacer()
                            if added.contains(player.userId) {
                                Image(systemName: "checkmark")
                                    .accessibilityLabel(String(localized: "myBookings.players.added"))
                            } else {
                                Button(String(localized: "myBookings.players.add")) { add(player) }
                                    .buttonStyle(.bordered)
                                    .disabled(adding != nil)
                            }
                        }
                    }
                }
                Section {
                    if let link {
                        ShareLink(
                            item: link,
                            subject: Text(String(localized: "myBookings.players.shareTitle")),
                            message: Text(String(localized: "myBookings.players.shareTitle"))
                        ) {
                            Label(String(localized: "myBookings.players.share"), systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button(String(localized: "myBookings.players.share"), systemImage: "link", action: makeLink)
                            .disabled(busy)
                    }
                    if liveLinks > 0 {
                        Button(String(localized: "myBookings.players.stopLinks"), role: .destructive, action: stopLinks)
                            .disabled(busy)
                    }
                } footer: {
                    if linksStopped {
                        Text(String(localized: "myBookings.players.linksStopped"))
                    } else if link != nil {
                        Text(String(localized: "myBookings.players.linkReady"))
                    } else if liveLinks > 0 {
                        Text(String(localized: "myBookings.players.liveLinks \(liveLinks)"))
                    }
                }
            }
            .navigationTitle(String(localized: "myBookings.players.sheetTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done"), action: close)
                }
            }
            .task { await loadCoPlayers() }
        }
    }

    private func close() {
        dismiss()
    }

    private func loadCoPlayers() async {
        guard let client = await session.client() else { return }
        coPlayers = (try? await client.listBookingCoPlayers(path: .init(id: bookingId)).ok.body.json.data) ?? []
        loaded = true
    }

    private func add(_ player: Components.Schemas.CoPlayer) {
        adding = player.userId
        problem = nil
        Task {
            defer { adding = nil }
            guard let client = await session.client() else { return }
            let response = try? await client.addBookingParticipant(
                path: .init(id: bookingId),
                body: .json(.init(userId: player.userId))
            )
            switch response {
            case .ok, .created: added.insert(player.userId)
            default: problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }

    private func makeLink() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.createBookingInviteLink(path: .init(id: bookingId))
            if case let .created(created) = response, let made = try? created.body.json.data,
                let url = URL(string: made.url)
            {
                link = url
                liveLinks += 1
                linksStopped = false
            } else {
                problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }

    private func stopLinks() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.revokeBookingInviteLinks(path: .init(id: bookingId))
            if case .ok = response {
                liveLinks = 0
                link = nil
                linksStopped = true
            } else {
                problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }
}
