import Foundation
import PlayerzAPI

/// A city the filters can offer (projectZ#667): `value` is what `?city=`
/// takes (the canonical key, or the typed text for a city outside the list),
/// `name` is in the app's language. One per city: «Sofia» and «София» are
/// one city since the server keys them.
struct CityChoice: Hashable, Identifiable {
    let value: String
    let name: String
    var id: String { value }
}

enum CityText {
    /// The name in the app's language (AppLanguageChoice).
    static func shown(_ names: Components.Schemas.CityNames) -> String {
        AppLanguageChoice.current == .en ? names.en : names.bg
    }
}

/// What the club and game filters can offer: `GET /venues/facets`, the cities
/// with a live venue and the sports with a live court. Nil on a failure, so a
/// caller keeps what it has.
enum VenueFacetChoices {
    static func load(_ client: Client) async -> (cities: [CityChoice], sports: [String])? {
        guard let data = try? await client.listVenueFacets().ok.body.json.data else { return nil }
        let cities = data.cities
            .map { CityChoice(value: $0.value, name: CityText.shown($0.names)) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        let found = Set(data.sports)
        // The spec's order first, then whatever the server added since this build.
        let sports = Sports.known.filter(found.contains) + found.subtracting(Sports.known).sorted()
        return (cities, sports)
    }
}
