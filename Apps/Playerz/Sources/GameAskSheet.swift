import PlayerzAPI
import SwiftUI

/// «Да поискаме ли място?»: a note for the organiser, and the request itself.
/// The same sheet from a card's «+» and from the game's screen.
struct GameAskSheet: View {
    enum Outcome {
        /// The game as the server answered it, the caller's request in it.
        case asked(Components.Schemas.OpenGame)
        /// What went wrong, in the user's words.
        case refused(String)
        case cancelled
    }

    let game: Components.Schemas.OpenGame
    @Bindable var session: SessionModel
    let finished: (Outcome) -> Void

    @State private var note = ""
    @State private var busy = false

    /// The server's limit, after it sanitises the note (#376).
    private let noteMax = 280

    var body: some View {
        BrandDarkSheet(
            title: String(localized: "games.askTitle"),
            subtitle: String(localized: "games.askWhere \(game.venue.name) \(GameText.when(game.startTs, timezone: game.timezone))")
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(String(localized: "games.noteLabel"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                TextField(String(localized: "games.notePlaceholder"), text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(.white)
                    .padding(Theme.Spacing.m)
                    .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
                    .accessibilityLabel(String(localized: "games.noteLabel"))
                // Over the limit: a warning sign as well as brighter text.
                HStack(spacing: Theme.Spacing.xs) {
                    if note.count > noteMax {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                    }
                    Text(String(localized: "games.noteHint \(noteMax - note.count)"))
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(note.count > noteMax ? 1 : 0.72))
            }
            Button(String(localized: "games.send")) { Task { await ask() } }
                .buttonStyle(.brandPrimary)
                .disabled(busy || note.count > noteMax)
                .padding(.top, Theme.Spacing.s)
            Button(String(localized: "games.back")) { finished(.cancelled) }
                .buttonStyle(.brandSecondary)
        }
    }

    private func ask() async {
        guard let client = await session.client() else { return }
        busy = true
        defer { busy = false }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let response = try await client.askToJoinGame(
                path: .init(id: game.id),
                body: .json(.init(note: trimmed.isEmpty ? nil : trimmed))
            )
            switch response {
            case .ok(let ok):
                finished(.asked(try ok.body.json.data))
            case .created(let created):
                finished(.asked(try created.body.json.data))
            default:
                let code = apiErrorCode(response)
                session.notice(refusal: code)
                finished(.refused(GameText.error(code)))
            }
        } catch {
            finished(.refused(GameText.error(nil)))
        }
    }
}
