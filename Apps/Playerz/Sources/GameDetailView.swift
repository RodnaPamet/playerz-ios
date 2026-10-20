import PlayerzAPI
import SwiftUI

/// One game (#510): its facts, and what the caller can do about it: ask for a
/// place, take the request back, or leave before the club's cutoff.
struct GameDetailView: View {
    @State private var game: Components.Schemas.OpenGame
    @Bindable var session: SessionModel
    /// The list behind this screen re-reads after a change.
    let changed: () async -> Void

    init(
        game: Components.Schemas.OpenGame,
        session: SessionModel,
        changed: @escaping () async -> Void
    ) {
        _game = State(initialValue: game)
        self.session = session
        self.changed = changed
    }

    @State private var asking = false
    @State private var note = ""
    @State private var busy = false
    @State private var problem: String?

    /// The server's limit, after it sanitises the note (#376).
    private let noteMax = 280

    var body: some View {
        List {
            Section {
                LabeledContent(String(localized: "games.detail.when"),
                               value: GameText.when(game.startTs, timezone: game.timezone))
                LabeledContent(String(localized: "games.detail.where"),
                               value: "\(game.venue.name), \(game.venue.city)")
                LabeledContent(String(localized: "games.detail.court"), value: game.courtName)
                LabeledContent(String(localized: "games.detail.sport"), value: GameText.sport(game.sport))
                LabeledContent(String(localized: "games.detail.players"),
                               value: String(localized: "games.players \(game.playersCount) \(game.capacity)"))
                LabeledContent(String(localized: "games.detail.level"),
                               value: GameText.level(min: game.levelMin, max: game.levelMax))
                LabeledContent(
                    String(localized: "games.detail.organiser"),
                    value: game.booker.firstName ?? String(localized: "games.organiserUnknown")
                )
            }
            if let text = game.note, !text.isEmpty {
                Section(String(localized: "games.detail.note")) { Text(text) }
            }
            Section {
                if let problem {
                    Text(problem).foregroundStyle(.red)
                }
                action
            } footer: {
                Text(String(localized: "games.detail.payAtClub"))
            }
        }
        .navigationTitle(GameText.sport(game.sport))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: problem) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
        .sheet(isPresented: $asking) { askSheet }
    }

    /// The caller's part: none yet, a request, a place, or the organiser's own game.
    @ViewBuilder private var action: some View {
        let viewer = game.viewer
        if viewer?.isBooker == true {
            Text(String(localized: "games.yours"))
        } else if let request = viewer?.request, request.status == .PENDING || request.status == .ACCEPTED {
            LabeledContent(String(localized: "games.detail.request"), value: GameText.status(request.status))
            // Leaving is possible until the club's cutoff; waiting can be withdrawn any time.
            if request.status == .PENDING || game.cutoffAt > .now {
                Button(role: .destructive) {
                    Task { await withdraw(request.id) }
                } label: {
                    Text(request.status == .PENDING
                         ? String(localized: "games.withdraw")
                         : String(localized: "games.leave"))
                }
                .disabled(busy)
            }
        } else if game.open {
            if let request = viewer?.request {
                LabeledContent(String(localized: "games.detail.request"), value: GameText.status(request.status))
            }
            Button(String(localized: "games.ask")) { asking = true }
                .disabled(busy || viewer?.request?.status == .DECLINED || viewer?.request?.status == .REMOVED)
        } else {
            Text(String(localized: "games.error.GAME_CLOSED")).foregroundStyle(.secondary)
        }
    }

    private var askSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "games.askWhere \(game.venue.name) \(GameText.when(game.startTs, timezone: game.timezone))"))
                }
                Section {
                    TextField(String(localized: "games.notePlaceholder"), text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(String(localized: "games.noteLabel"))
                } footer: {
                    Text(String(localized: "games.noteHint \(noteMax - note.count)"))
                        .foregroundStyle(note.count > noteMax ? .red : .secondary)
                }
            }
            .navigationTitle(String(localized: "games.askTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "games.back")) { asking = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "games.send")) {
                        Task { await ask() }
                    }
                    .disabled(busy || note.count > noteMax)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func ask() async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await client.askToJoinGame(
                path: .init(id: game.id),
                body: .json(.init(note: trimmed.isEmpty ? nil : trimmed))
            )
            switch response {
            case .ok(let ok):
                game = try ok.body.json.data
            case .created(let created):
                game = try created.body.json.data
            default:
                let code = apiErrorCode(response)
                session.notice(refusal: code)
                problem = GameText.error(code)
            }
            asking = false
            note = ""
            await changed()
        } catch {
            problem = GameText.error(nil)
            asking = false
        }
    }

    private func withdraw(_ requestId: String) async {
        guard let client = await session.client() else { return }
        busy = true
        problem = nil
        defer { busy = false }
        do {
            let response = try await client.withdrawGameRequest(path: .init(id: requestId))
            if case .noContent = response {
                await reload()
                await changed()
            } else {
                problem = GameText.error(apiErrorCode(response))
            }
        } catch {
            problem = GameText.error(nil)
        }
    }

    private func reload() async {
        guard let client = await session.client() else { return }
        if let fresh = try? await client.getOpenGame(path: .init(id: game.id)).ok.body.json.data {
            game = fresh
        }
    }
}
