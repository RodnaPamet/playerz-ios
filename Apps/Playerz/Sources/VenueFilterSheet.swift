import SwiftUI

/// «Филтри» for the club list: city, sport, indoor or outdoor. The choices are
/// a draft until «Покажи клубовете», so the list is read once, not per tap.
struct VenueFilterSheet: View {
    let cities: [String]
    let sports: [String]
    /// «Близо до мен» is searched by sport alone.
    let near: Bool
    let apply: (VenueFilters) -> Void

    @State private var draft: VenueFilters

    init(filters: VenueFilters, cities: [String], sports: [String], near: Bool, apply: @escaping (VenueFilters) -> Void) {
        _draft = State(initialValue: filters)
        self.cities = cities
        self.sports = sports
        self.near = near
        self.apply = apply
    }

    var body: some View {
        BrandDarkSheet(
            title: String(localized: "venues.filters"),
            subtitle: near ? String(localized: "venues.filter.nearNote") : nil
        ) {
            if !near, !cities.isEmpty {
                group(String(localized: "venues.filter.city")) {
                    BrandChip(String(localized: "venues.filter.allCities"), isSelected: draft.city == nil) {
                        draft.city = nil
                    }
                    ForEach(cities, id: \.self) { city in
                        BrandChip(city, isSelected: draft.city == city) { draft.city = city }
                    }
                }
            }
            if !sports.isEmpty {
                group(String(localized: "venues.filter.sport")) {
                    BrandChip(String(localized: "games.filter.allSports"), isSelected: draft.sport == nil) {
                        draft.sport = nil
                    }
                    ForEach(sports, id: \.self) { sport in
                        BrandChip(GameText.sport(sport), isSelected: draft.sport == sport) { draft.sport = sport }
                    }
                }
            }
            if !near {
                group(String(localized: "venues.filter.court")) {
                    BrandChip(String(localized: "venues.filter.anyCourt"), isSelected: draft.indoor == nil) {
                        draft.indoor = nil
                    }
                    BrandChip(String(localized: "venues.filter.indoor"), isSelected: draft.indoor == true) {
                        draft.indoor = true
                    }
                    BrandChip(String(localized: "venues.filter.outdoor"), isSelected: draft.indoor == false) {
                        draft.indoor = false
                    }
                }
            }
            // The same order and widths as the games' «Филтри» (GamesFilterSheet).
            Button(String(localized: "venues.filter.show")) { apply(draft) }
                .buttonStyle(.brandPrimary)
                .padding(.top, Theme.Spacing.s)
            Button(String(localized: "venues.filter.clear")) { draft = VenueFilters() }
                .buttonStyle(.brandSecondary)
                .disabled(draft == VenueFilters())
        }
    }

    /// A named row of chips that scrolls sideways out to the sheet's edges.
    private func group(_ title: String, @ViewBuilder chips: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityAddTraits(.isHeader)
            BrandChipRow { chips() }
                // The row brings its own side margin; the sheet has one already.
                .padding(.horizontal, -Theme.Spacing.l)
        }
    }
}

#Preview {
    VenueFilterSheet(
        filters: VenueFilters(city: "София"), cities: ["Пловдив", "София"], sports: ["TENNIS", "PADEL"], near: false
    ) { _ in }
}
