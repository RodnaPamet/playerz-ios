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
    @FocusState private var typing: Bool

    var body: some View {
        BrandDarkSheet(title: String(localized: "tournaments.partner.label")) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityHidden(true)
                TextField(String(localized: "tournaments.partner.placeholder"), text: $term)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($typing)
                    .foregroundStyle(Theme.Palette.onHeader)
            }
            .padding(Theme.Spacing.m)
            .frame(minHeight: Theme.minTarget)
            .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
            if term.count < 2 {
                note(String(localized: "tournaments.partner.hint"))
            } else if searched, results.isEmpty {
                note(String(localized: "tournaments.partner.none"))
            }
            ForEach(results, id: \.userId) { card in
                BrandSheetRow(title: card.name ?? String(localized: "tournaments.unnamed"), systemImage: "person") {
                    chosen(card)
                }
            }
            Button(String(localized: "common.close"), action: close)
                .buttonStyle(.brandSecondary)
                .padding(.top, Theme.Spacing.s)
        }
        // Straight to the name: the sheet is for typing one.
        .onAppear { typing = true }
        .task(id: term) { await search() }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.72))
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
