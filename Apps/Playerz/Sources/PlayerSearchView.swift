import PlayerzAPI
import SwiftUI

/// «Ново съобщение» (#484): find a player by name, see their public card, and
/// write to them. Answers the conversation's id.
struct PlayerSearchView: View {
    @Bindable var session: SessionModel
    let opened: (String) -> Void

    @State private var query = ""
    @State private var results: [Components.Schemas.PlayerCard] = []
    @State private var searched = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    /// The server searches from this many letters on.
    private let minLetters = 2

    var body: some View {
        NavigationStack {
            List {
                if query.count < minLetters {
                    Text(String(localized: "messages.search.hint \(minLetters)")).foregroundStyle(.secondary)
                } else if failed {
                    Text(String(localized: "messages.search.failed")).foregroundStyle(.red)
                } else if searched && results.isEmpty {
                    ContentUnavailableView(
                        String(localized: "messages.search.none"),
                        systemImage: "person.fill.questionmark",
                        description: Text(String(localized: "messages.search.noneHint"))
                    )
                }
                ForEach(results, id: \.userId) { card in
                    NavigationLink {
                        PlayerCardView(userId: card.userId, session: session, opened: opened)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(card.name ?? String(localized: "messages.unnamed"))
                            Text(levels(card)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "messages.new"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: String(localized: "messages.search.placeholder"))
            .task(id: query) { await search() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "messages.cancel")) { dismiss() }
                }
            }
        }
    }

    private func levels(_ card: Components.Schemas.PlayerCard) -> String {
        card.sports.map { "\(GameText.sport($0.sport)) \($0.level)" }.joined(separator: " · ")
    }

    /// Debounced by `task(id:)`: a new letter cancels the wait for the last.
    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= minLetters else {
            results = []
            searched = false
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, let client = await session.client() else { return }
        do {
            results = try await client.searchPlayers(query: .init(q: q)).ok.body.json.data
            failed = false
        } catch {
            if !Task.isCancelled { failed = true }
        }
        searched = true
    }
}

/// A player's public card (#375): name and levels, never a contact, and «Пиши».
struct PlayerCardView: View {
    let userId: String
    @Bindable var session: SessionModel
    let opened: (String) -> Void

    @State private var card: Components.Schemas.PlayerCard?
    @State private var busy = false
    @State private var problem: String?

    var body: some View {
        List {
            if let card {
                Section {
                    Text(card.name ?? String(localized: "messages.unnamed")).font(.title2.weight(.semibold))
                }
                Section(String(localized: "messages.card.sports")) {
                    if card.sports.isEmpty {
                        Text(String(localized: "messages.card.noSports")).foregroundStyle(.secondary)
                    }
                    ForEach(card.sports, id: \.sport) { s in
                        LabeledContent(GameText.sport(s.sport), value: "\(s.level)")
                    }
                }
                Section {
                    if let problem { Text(problem).foregroundStyle(.red) }
                    Button(String(localized: "messages.write")) { Task { await write() } }
                        .disabled(busy)
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let client = await session.client() else { return }
            card = try? await client.getPlayerCard(path: .init(id: userId)).ok.body.json.data
        }
    }

    private func write() async {
        busy = true
        problem = nil
        defer { busy = false }
        switch await ConversationOpener.open(session, .case1(.init(playerId: userId))) {
        case .success(let id): opened(id)
        case .failure(let failure): problem = failure.text
        }
    }
}

/// Opens (or finds) a conversation: with a club by its slug, or with a player
/// on one of the caller's bookings by their place on it (#375). Answers its id,
/// or the refusal in the user's words.
enum ConversationOpener {
    static func open(
        _ session: SessionModel,
        _ request: Components.Schemas.OpenConversationRequest
    ) async -> Result<String, OpenFailure> {
        guard let client = await session.client() else { return .failure(.init(text: ConversationText.error(nil))) }
        do {
            let response = try await client.openConversation(body: .json(request))
            switch response {
            case .ok(let ok): return .success(try ok.body.json.data.id)
            case .created(let created): return .success(try created.body.json.data.id)
            default: return .failure(.init(text: ConversationText.error(apiErrorCode(response))))
            }
        } catch {
            return .failure(.init(text: ConversationText.error(nil)))
        }
    }

    struct OpenFailure: Error { let text: String }
}
