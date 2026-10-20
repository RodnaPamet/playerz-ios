import PlayerzAPI
import SwiftUI

/// A doubles partner (#22): any player found by name, two letters at least,
/// the same search «Нов разговор» uses.
struct PartnerPickerSheet: View {
    @Bindable var session: SessionModel
    let chosen: (Components.Schemas.PlayerCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var results: [Components.Schemas.PlayerCard] = []
    @State private var searched = false

    var body: some View {
        NavigationStack {
            List {
                if term.count < 2 {
                    Text(String(localized: "tournaments.partner.hint")).foregroundStyle(.secondary)
                } else if searched, results.isEmpty {
                    Text(String(localized: "tournaments.partner.none")).foregroundStyle(.secondary)
                }
                ForEach(results, id: \.userId) { card in
                    Button(card.name ?? String(localized: "tournaments.unnamed")) { chosen(card) }
                        .tint(.primary)
                }
            }
            .searchable(text: $term, prompt: String(localized: "tournaments.partner.placeholder"))
            .navigationTitle(String(localized: "tournaments.partner.label"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close"), action: close)
                }
            }
            .task(id: term) { await search() }
        }
    }

    private func close() {
        dismiss()
    }

    private func search() async {
        let q = term.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else {
            results = []
            searched = false
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled, let client = await session.client() else { return }
        results = (try? await client.searchPlayers(query: .init(q: q)).ok.body.json.data) ?? []
        searched = true
    }
}
