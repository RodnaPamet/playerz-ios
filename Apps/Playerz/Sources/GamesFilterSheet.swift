import PlayerzAPI
import SwiftUI

/// «Филтри» for the open games: the day, the part of the day, the city and
/// the kind of court, what the server filters by besides the sport. Nothing
/// changes until «Покажи игрите».
struct GamesFilterSheet: View {
    let days: [VenueDay]
    /// The cities with a club; empty hides the section.
    let cities: [CityChoice]
    let apply: (GamesFilterChoice) -> Void

    @State private var draft: GamesFilterChoice

    init(days: [VenueDay], cities: [CityChoice], current: GamesFilterChoice, apply: @escaping (GamesFilterChoice) -> Void) {
        self.days = days
        self.cities = cities
        self.apply = apply
        _draft = State(initialValue: current)
    }

    var body: some View {
        BrandDarkSheet(title: String(localized: "games.filters.title")) {
            section(String(localized: "games.filter.day")) {
                BrandChip(String(localized: "games.filter.anyDay"), isSelected: draft.day == nil) { draft.day = nil }
                ForEach(days) { item in
                    BrandChip(GameText.filterDay(item), isSelected: draft.day == item) { draft.day = item }
                }
            }
            section(String(localized: "games.filter.time")) {
                BrandChip(String(localized: "games.filter.anyTime"), isSelected: draft.part == nil) { draft.part = nil }
                ForEach(DayPart.allCases, id: \.self) { part in
                    BrandChip(part.label, isSelected: draft.part == part) { draft.part = part }
                }
            }
            if !cities.isEmpty {
                section(String(localized: "games.filter.city")) {
                    BrandChip(String(localized: "games.filter.anyCity"), isSelected: draft.city == nil) { draft.city = nil }
                    ForEach(cities) { item in
                        BrandChip(item.name, isSelected: draft.city == item.value) { draft.city = item.value }
                    }
                }
            }
            section(String(localized: "venues.filter.court")) {
                BrandChip(String(localized: "venues.filter.anyCourt"), isSelected: draft.indoor == nil) { draft.indoor = nil }
                BrandChip(String(localized: "venues.filter.indoor"), isSelected: draft.indoor == true) { draft.indoor = true }
                BrandChip(String(localized: "venues.filter.outdoor"), isSelected: draft.indoor == false) { draft.indoor = false }
            }
            Button(String(localized: "games.filters.show")) { apply(draft) }
                .buttonStyle(.brandPrimary)
                .padding(.top, Theme.Spacing.s)
            Button(String(localized: "games.filters.clear")) { draft = GamesFilterChoice() }
                .buttonStyle(.brandSecondary)
                .disabled(draft == GamesFilterChoice())
        }
    }

    private func section<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityAddTraits(.isHeader)
            // To the sheet's edges, so a long row visibly runs on; the same
            // row as the clubs' «Филтри», with its cap on the text size.
            BrandChipRow { chips() }
                .padding(.horizontal, -Theme.Spacing.l)
        }
    }
}

#Preview {
    GamesFilterSheet(
        days: VenueDay.upcoming(inTimeZone: "Europe/Sofia"),
        cities: [CityChoice(value: "sofia", name: "София"), CityChoice(value: "plovdiv", name: "Пловдив")],
        current: GamesFilterChoice()
    ) { _ in }
}
