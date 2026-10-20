import PlayerzAPI
import SwiftUI

/// «Класиране» (playerz-ios#18), the web's club leaderboard: the club's ranked
/// players in one sport, by level. A player with 5 confirmed matches there is
/// ranked, unless they hide their level.
struct ClubLeaderboardView: View {
    let slug: String
    @Bindable var session: SessionModel

    @State private var board: Components.Schemas.ClubLeaderboard?
    @State private var sport: String?
    @State private var failed = false

    var body: some View {
        Group {
            if let board {
                List {
                    if board.sports.count > 1 {
                        Picker(String(localized: "club.leaderboard.sport"), selection: $sport) {
                            ForEach(board.sports, id: \.self) { sport in
                                Text(GameText.sport(sport)).tag(Optional(sport))
                            }
                        }
                    }
                    if board.sport == nil {
                        Text(String(localized: "club.leaderboard.noResults")).foregroundStyle(.secondary)
                    } else if board.rows.isEmpty {
                        Text(String(localized: "club.leaderboard.empty")).foregroundStyle(.secondary)
                    }
                    Section {
                        ForEach(board.rows, id: \.userId) { row in
                            ClubLeaderboardRow(row: row)
                        }
                    } footer: {
                        Text(String(localized: "club.leaderboard.hint"))
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "club.failed"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "club.leaderboard.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sport) { await load() }
    }

    private func retry() {
        failed = false
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            let fresh = try await client
                .getClubLeaderboard(path: .init(slug: slug), query: .init(sport: sport))
                .ok.body.json.data
            board = fresh
            if sport == nil { sport = fresh.sport }
            failed = false
        } catch {
            failed = board == nil
        }
    }
}
