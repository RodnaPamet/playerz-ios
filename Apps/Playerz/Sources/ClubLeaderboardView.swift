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
                if board.sport == nil || board.rows.isEmpty {
                    // A short title over the sentence that says why.
                    BrandEmptyState(
                        systemImage: "chart.bar",
                        title: String(localized: "club.leaderboard.emptyTitle"),
                        message: board.sport == nil
                            ? String(localized: "club.leaderboard.noResults")
                            : String(localized: "club.leaderboard.empty")
                    )
                } else {
                    List {
                        Section {
                            ForEach(board.rows, id: \.userId) { row in
                                ClubLeaderboardRow(row: row)
                            }
                        } footer: {
                            Text(String(localized: "club.leaderboard.hint"))
                        }
                        .brandListRow()
                    }
                }
            } else if failed {
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "club.failed")) {
                    Button(String(localized: "venues.retry"), action: retry)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView()
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(String(localized: "club.leaderboard.title"))
        // The sports as chips under the band, as a venue's days: they stay
        // while another sport's board loads.
        .brandChipBar {
            if let sports = board?.sports, sports.count > 1 {
                BrandChipRow {
                    ForEach(sports, id: \.self) { item in
                        BrandChip(GameText.sport(item), systemImage: GameSport.symbol(item), isSelected: sport == item) {
                            sport = item
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "club.leaderboard.sport"))
            }
        }
        .brandHeader(.back(String(localized: "club.leaderboard.title")))
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
