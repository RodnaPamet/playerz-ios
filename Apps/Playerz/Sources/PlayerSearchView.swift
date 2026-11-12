import PlayerzAPI
import SwiftUI

/// «Ново съобщение» (#484): find a player by name, see their public card, and
/// write to them. Answers the conversation's id.
struct PlayerSearchView: View {
    @Bindable var session: SessionModel
    let opened: (String) -> Void

    /// A DEBUG launch can type a name in (`PLAYERZ_SEARCH`).
    @State private var query = DebugLaunch.search ?? ""
    @State private var results: [Components.Schemas.PlayerCard] = []
    @State private var searched = false
    @State private var failed = false
    /// A DEBUG launch can open the first result's card (`PLAYERZ_OPEN=card`).
    @State private var debugCard: String?

    /// The server searches from this many letters on.
    private let minLetters = 2

    var body: some View {
        NavigationStack {
            content
                .brandPage()
                // Hidden with the system bar; still what VoiceOver calls the screen.
                .navigationTitle(String(localized: "messages.new"))
                // The field under the band: `searchable` lives in the system bar this hides.
                .brandChipBar { PlayerSearchField(query: $query) }
                // The sheet's first screen: the band's back button closes it.
                .brandHeader(.back(String(localized: "messages.new")))
                .task(id: query) { await search() }
                .navigationDestination(item: $debugCard) { id in
                    PlayerCardView(userId: id, session: session, opened: opened)
                }
        }
    }

    @ViewBuilder private var content: some View {
        if query.count < minLetters {
            BrandEmptyState(systemImage: "magnifyingglass", title: String(localized: "messages.search.hint \(minLetters)"))
        } else if failed {
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "messages.search.failed"))
        } else if searched && results.isEmpty {
            BrandEmptyState(
                systemImage: "person.fill.questionmark",
                title: String(localized: "messages.search.none"),
                message: String(localized: "messages.search.noneHint")
            )
        } else {
            List(results, id: \.userId) { card in
                NavigationLink {
                    PlayerCardView(userId: card.userId, session: session, opened: opened)
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        BrandAvatar(name: card.name, url: session.mediaURL(card.avatarUrl))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.name ?? String(localized: "messages.unnamed")).font(Theme.Typography.rowTitle)
                            Text(levels(card)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .brandListRow()
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
            if DebugLaunch.open == "card",
               let id = DebugLaunch.pick("card", "first", from: results.map(\.userId)) { debugCard = id }
        } catch {
            if !Task.isCancelled { failed = true }
        }
        searched = true
    }
}

/// The name to search for, on the page under the band: a rounded field with
/// a magnifier, and a clear button once something is typed.
private struct PlayerSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(String(localized: "messages.search.placeholder"), text: $query)
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .frame(minHeight: Theme.minTarget)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "messages.search.clear"))
            }
        }
        .padding(.leading, Theme.Spacing.l)
        .padding(.trailing, query.isEmpty ? Theme.Spacing.l : Theme.Spacing.xs)
        .background(Theme.Palette.card, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.Palette.hairline))
        .padding(.horizontal, Theme.Spacing.l)
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
        Group {
            if let card {
                List {
                    Group {
                        Section {
                            HStack(spacing: Theme.Spacing.m) {
                                BrandAvatar(name: card.name, url: session.mediaURL(card.avatarUrl), side: 64)
                                Text(name(card))
                                    .font(Theme.Typography.cardTitle)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        Section(String(localized: "messages.card.sports")) {
                            if card.sports.isEmpty {
                                Text(String(localized: "messages.card.noSports")).foregroundStyle(.secondary)
                            }
                            ForEach(card.sports, id: \.sport) { s in
                                LabeledContent(GameText.sport(s.sport), value: "\(s.level)")
                            }
                        }
                        if let problem {
                            Section { Text(problem).foregroundStyle(Theme.Palette.danger) }
                        }
                    }
                    .brandListRow()
                    // The card's one action: the accent pill, on the page.
                    Section {
                        Button(String(localized: "messages.write")) { Task { await write() } }
                            .buttonStyle(.brandPrimary)
                            .disabled(busy)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } else {
                ProgressView()
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(card.map(name) ?? "")
        .brandHeader(.back(card.map(name) ?? ""))
        .task {
            guard let client = await session.client() else { return }
            card = try? await client.getPlayerCard(path: .init(id: userId)).ok.body.json.data
        }
    }

    private func name(_ card: Components.Schemas.PlayerCard) -> String {
        card.name ?? String(localized: "messages.unnamed")
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
            default:
                let code = apiErrorCode(response)
                await session.notice(refusal: code)
                return .failure(.init(text: ConversationText.error(code)))
            }
        } catch {
            return .failure(.init(text: ConversationText.error(nil)))
        }
    }

    struct OpenFailure: Error { let text: String }
}
