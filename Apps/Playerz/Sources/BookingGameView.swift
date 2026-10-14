import PlayerzAPI
import SwiftUI

/// Open play on one of the caller's bookings (#510): the booker opens, changes
/// or closes the game and answers each request; anyone else on the booking
/// sees their own request.
struct BookingGameView: View {
    let bookingId: String
    @Bindable var session: SessionModel

    @State private var game: Components.Schemas.BookingGame?
    @State private var failed = false
    @State private var busy = false
    @State private var problem: String?

    // The form, filled from the game when there is one.
    @State private var spots = 1
    @State private var levelMin: Int?
    @State private var levelMax: Int?
    @State private var note = ""

    var body: some View {
        Group {
            if let game {
                form(game)
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "bookingGame.failed"))
                } actions: {
                    Button(String(localized: "venues.retry")) { Task { await load() } }
                }
            } else {
                ProgressView(String(localized: "common.loading"))
            }
        }
        .navigationTitle(String(localized: "bookingGame.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: problem) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
    }

    @ViewBuilder private func form(_ g: Components.Schemas.BookingGame) -> some View {
        List {
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            if g.viewerRole == .PARTICIPANT {
                Section {
                    if let mine = g.myRequest {
                        LabeledContent(String(localized: "games.detail.request"), value: GameText.status(mine.status))
                    } else {
                        Text(String(localized: "bookingGame.participant"))
                    }
                }
            } else {
                Section {
                    if let open = g.game, open.open {
                        LabeledContent(String(localized: "bookingGame.state"),
                                       value: String(localized: "games.spotsLeft \(open.spotsLeft)"))
                    } else {
                        Text(String(localized: "bookingGame.intro"))
                    }
                } footer: {
                    Text(String(localized: "bookingGame.until \(GameText.when(g.cutoffAt, timezone: "Europe/Sofia"))"))
                }
                if g.canOpen && g.maxSpots > 0 {
                    Section {
                        Stepper(value: $spots, in: 1...max(1, g.maxSpots)) {
                            Text(String(localized: "bookingGame.spots \(spots)"))
                        }
                        Picker(String(localized: "bookingGame.levelMin"), selection: $levelMin) {
                            Text(String(localized: "games.level.any")).tag(Int?.none)
                            ForEach(1...7, id: \.self) { Text("\($0)").tag(Optional($0)) }
                        }
                        Picker(String(localized: "bookingGame.levelMax"), selection: $levelMax) {
                            Text(String(localized: "games.level.any")).tag(Int?.none)
                            ForEach(1...7, id: \.self) { Text("\($0)").tag(Optional($0)) }
                        }
                        TextField(String(localized: "bookingGame.note"), text: $note, axis: .vertical)
                            .lineLimit(2...4)
                        Button(g.game?.open == true
                               ? String(localized: "bookingGame.save")
                               : String(localized: "bookingGame.open")) {
                            Task { await open() }
                        }
                        .disabled(busy || note.count > 280 || !levelsInOrder)
                    }
                }
                if g.game?.open == true {
                    Section {
                        Button(String(localized: "bookingGame.stop"), role: .destructive) {
                            Task { await close() }
                        }
                        .disabled(busy)
                    }
                }
                Section(String(localized: "bookingGame.requests")) {
                    if g.requests.isEmpty {
                        Text(String(localized: "bookingGame.noRequests")).foregroundStyle(.secondary)
                    }
                    ForEach(g.requests, id: \.id) { request in
                        RequestRow(request: request, busy: busy) { accept in
                            Task { await answer(request.id, accept: accept) }
                        }
                    }
                }
            }
        }
        .refreshable { await load() }
    }

    private var levelsInOrder: Bool {
        guard let lo = levelMin, let hi = levelMax else { return true }
        return lo <= hi
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            let fresh = try await client.getBookingGame(path: .init(id: bookingId)).ok.body.json.data
            show(fresh)
            failed = false
        } catch {
            failed = game == nil
        }
    }

    /// The game as the server has it now, and the form from it.
    private func show(_ fresh: Components.Schemas.BookingGame) {
        game = fresh
        if let open = fresh.game {
            spots = max(1, min(open.spotsLeft, fresh.maxSpots))
            levelMin = open.levelMin
            levelMax = open.levelMax
            note = open.note ?? ""
        } else {
            spots = max(1, min(spots, fresh.maxSpots))
        }
    }

    private func open() async {
        guard let client = await session.client() else { return }
        await act {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await client.openBookingGame(
                path: .init(id: bookingId),
                body: .json(.init(
                    spots: spots,
                    levelMin: levelMin,
                    levelMax: levelMax,
                    note: trimmed.isEmpty ? nil : trimmed
                ))
            )
            if case .ok(let ok) = response { return try ok.body.json.data }
            throw Refused(code: apiErrorCode(response))
        }
    }

    private func close() async {
        guard let client = await session.client() else { return }
        await act {
            let response = try await client.closeBookingGame(path: .init(id: bookingId))
            if case .ok(let ok) = response { return try ok.body.json.data }
            throw Refused(code: apiErrorCode(response))
        }
    }

    private func answer(_ requestId: String, accept: Bool) async {
        guard let client = await session.client() else { return }
        await act {
            if accept {
                let response = try await client.acceptGameRequest(
                    path: .init(id: bookingId, requestId: requestId)
                )
                if case .ok(let ok) = response { return try ok.body.json.data }
                throw Refused(code: apiErrorCode(response))
            }
            let response = try await client.declineGameRequest(
                path: .init(id: bookingId, requestId: requestId)
            )
            if case .ok(let ok) = response { return try ok.body.json.data }
            throw Refused(code: apiErrorCode(response))
        }
    }

    private struct Refused: Error { let code: String? }

    /// One change: busy while it runs, the game as it comes back, or the refusal.
    private func act(_ change: () async throws -> Components.Schemas.BookingGame) async {
        busy = true
        problem = nil
        defer { busy = false }
        do {
            show(try await change())
        } catch let refused as Refused {
            problem = GameText.error(refused.code)
            await load()
        } catch {
            problem = GameText.error(nil)
        }
    }
}

/// One request to join, as the booker sees it: who, their levels, the note.
private struct RequestRow: View {
    let request: Components.Schemas.OpenGameJoinRequest
    let busy: Bool
    let answer: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(request.player.name ?? String(localized: "games.organiserUnknown")).font(.headline)
                if !request.player.sports.isEmpty {
                    Text(request.player.sports
                        .map { "\(GameText.sport($0.sport)) \($0.level)" }
                        .joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let note = request.note, !note.isEmpty {
                    Text(note).font(.subheadline)
                }
                Text(GameText.status(request.status)).font(.caption.weight(.semibold))
            }
            .accessibilityElement(children: .combine)
            if request.status == .PENDING {
                HStack {
                    Button(String(localized: "bookingGame.accept")) { answer(true) }
                        .buttonStyle(.borderedProminent)
                    Button(String(localized: "bookingGame.decline")) { answer(false) }
                        .buttonStyle(.bordered)
                }
                .disabled(busy)
            }
        }
    }
}
