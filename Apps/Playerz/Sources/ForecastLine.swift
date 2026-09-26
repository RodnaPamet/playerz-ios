import CoreLocation
import Foundation
import Observation
import WeatherKit

/// A one-line forecast for an OUTDOOR court at a given hour (#211).
///
/// ═══ WHY NATIVE WEATHERKIT AND NOT THE REST API ═══
///
/// The framework needs no key and no Services ID — only the WeatherKit
/// capability on the App ID — so it works as soon as the app exists. The REST
/// API needs a Services ID that is not registered yet (a probe returned
/// `401 NOT_ENABLED`), and it is the right answer LATER, because it lets the
/// server cache one forecast per venue-hour and serve the PWA from the same
/// data. Owner's sequencing: native now, REST later.
///
/// ═══ FAILURE IS SILENCE, ON PURPOSE ═══
///
/// No line is better than an error beside a court. Someone choosing a slot does
/// not need to know that a weather service timed out, and a red row next to a
/// bookable court reads as "something is wrong with this court".
@MainActor
@Observable
final class ForecastLine {
    private(set) var summary: String?

    private let service = WeatherService.shared
    private var loaded: Set<String> = []

    /// Fetch once per (venue, hour). The forecast for a court at 18:00 is the
    /// same for everyone looking at it, so repeating the call per row would
    /// spend the quota on identical answers.
    func load(lat: Double, lng: Double, at date: Date) async {
        let key = "\(lat),\(lng),\(Int(date.timeIntervalSince1970 / 3600))"
        guard !loaded.contains(key) else { return }
        loaded.insert(key)

        do {
            let location = CLLocation(latitude: lat, longitude: lng)
            let hourly = try await service.weather(for: location, including: .hourly)

            // The forecast hour covering this slot. `first(where:)` rather than
            // an index: the hourly series starts at the current hour, not at
            // midnight, so any arithmetic on position is wrong the moment the
            // request is not made at :00.
            guard let hour = hourly.forecast.first(where: {
                $0.date <= date && date < $0.date.addingTimeInterval(3600)
            }) else { return }

            let temperature = hour.temperature.formatted(
                .measurement(width: .narrow, usage: .weather)
            )
            let rain = hour.precipitationChance
            // Precipitation chance only when it is worth acting on. A "3%"
            // beside every court is noise that trains people to ignore the row.
            summary = rain >= 0.2 ? "\(temperature) · \(Int(rain * 100))%" : temperature
        } catch {
            // Deliberately silent. See the type docs.
        }
    }
}
