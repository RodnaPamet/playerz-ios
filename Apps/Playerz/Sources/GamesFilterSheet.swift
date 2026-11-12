import PlayerzAPI
import SwiftUI

/// «Филтри» for the open games: the day and the city, the two things besides
/// the sport that the server filters by. Nothing changes until «Покажи игрите».
struct GamesFilterSheet: View {
    let days: [VenueDay]
    /// The cities the listed clubs are in; empty hides the section.
    let cities: [String]
    let apply: (VenueDay?, String?) -> Void

    @State private var day: VenueDay?
    @State private var city: String?

    init(days: [VenueDay], cities: [String], day: VenueDay?, city: String?, apply: @escaping (VenueDay?, String?) -> Void) {
        self.days = days
        self.cities = cities
        self.apply = apply
        _day = State(initialValue: day)
        _city = State(initialValue: city)
    }

    var body: some View {
        BrandDarkSheet(title: String(localized: "games.filters.title")) {
            section(String(localized: "games.filter.day")) {
                BrandChip(String(localized: "games.filter.anyDay"), isSelected: day == nil) { day = nil }
                ForEach(days) { item in
                    BrandChip(GameText.filterDay(item), isSelected: day == item) { day = item }
                }
            }
            if !cities.isEmpty {
                section(String(localized: "games.filter.city")) {
                    BrandChip(String(localized: "games.filter.anyCity"), isSelected: city == nil) { city = nil }
                    ForEach(cities, id: \.self) { item in
                        BrandChip(item, isSelected: city == item) { city = item }
                    }
                }
            }
            Button(String(localized: "games.filters.show")) { apply(day, city) }
                .buttonStyle(.brandPrimary)
                .padding(.top, Theme.Spacing.s)
            Button(String(localized: "games.filters.clear")) {
                day = nil
                city = nil
            }
            .buttonStyle(.brandSecondary)
            .disabled(day == nil && city == nil)
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
        cities: ["София", "Пловдив"], day: nil, city: nil
    ) { _, _ in }
}
