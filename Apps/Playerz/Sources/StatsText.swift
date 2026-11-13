import Foundation
import PlayerzAPI

/// The words and numbers of «Прогрес» and «Мачове» (playerz-ios#95).
enum StatsText {
    /// «4,2», one decimal in the app's language.
    nonisolated static func level(_ level: Double) -> String {
        level.formatted(.number.precision(.fractionLength(1)))
    }

    /// «+0,30» / «−0,15»: a level's change, signed, two decimals.
    nonisolated static func change(_ change: Double) -> String {
        let magnitude = abs(change).formatted(.number.precision(.fractionLength(2)))
        return change > 0 ? "+\(magnitude)" : change < 0 ? "−\(magnitude)" : magnitude
    }

    /// «59 %» in Bulgarian, "59%" in English.
    nonisolated static func percent(_ value: Int) -> String {
        (Double(value) / 100).formatted(.percent.precision(.fractionLength(0)))
    }

    /// «П», «З», «Р»: a result in one letter, for the form row.
    nonisolated static func letter(_ outcome: String) -> String {
        switch outcome {
        case "WIN": String(localized: "stats.outcome.win.short")
        case "LOSS": String(localized: "stats.outcome.loss.short")
        default: String(localized: "stats.outcome.draw.short")
        }
    }

    /// «Победа», «Загуба», «Равен».
    nonisolated static func outcome(_ outcome: String) -> String {
        switch outcome {
        case "WIN": String(localized: "stats.outcome.win")
        case "LOSS": String(localized: "stats.outcome.loss")
        default: String(localized: "stats.outcome.draw")
        }
    }

    /// «Победи подред: 3», for the current streak.
    nonisolated static func streak(_ outcome: String, _ length: Int) -> String {
        switch outcome {
        case "WIN": String(localized: "stats.form.streak.win \(length)")
        case "LOSS": String(localized: "stats.form.streak.loss \(length)")
        default: String(localized: "stats.form.streak.draw \(length)")
        }
    }

    /// «6–4 3–6 6–1», the caller's side first.
    nonisolated static func score(_ sets: [[Int]]) -> String {
        sets.filter { $0.count == 2 }.map { "\($0[0])–\($0[1])" }.joined(separator: " ")
    }

    /// A person in a list: their name, or «Играч» for one without.
    nonisolated static func name(_ person: Components.Schemas.StatsPerson) -> String {
        person.name ?? String(localized: "stats.unnamed")
    }

    /// «Иван и Мария».
    nonisolated static func names(_ people: [Components.Schemas.StatsPerson]) -> String {
        people.map(name).formatted(.list(type: .and))
    }

    /// The weekday a Monday-first index names, in the app's language.
    nonisolated static func weekday(_ mondayFirst: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLanguageChoice.chosen.withLock { $0.locale }
        let symbols = calendar.standaloneWeekdaySymbols
        return symbols[(mondayFirst + 1) % 7]
    }

    /// «П», «В»…: a weekday's first letter, for a chart's axis.
    nonisolated static func weekdayInitial(_ mondayFirst: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLanguageChoice.chosen.withLock { $0.locale }
        return calendar.veryShortStandaloneWeekdaySymbols[(mondayFirst + 1) % 7]
    }

    /// The first day of a `YYYY-MM` month, in Sofia.
    nonisolated static func month(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sofia") ?? .current
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
    }

    /// «ное.»: a month's short name in the app's language, for a chart's axis
    /// (the chart's own month format gave numbers in Bulgarian).
    nonisolated static func monthShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguageChoice.chosen.withLock { $0.locale }
        formatter.timeZone = TimeZone(identifier: "Europe/Sofia")
        formatter.setLocalizedDateFormatFromTemplate("LLL")
        return formatter.string(from: date)
    }

    /// «съб, 14 ное»: when a match was played, in Sofia.
    nonisolated static func day(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(timeZone: TimeZone(identifier: "Europe/Sofia") ?? .current)
                .weekday(.abbreviated).day().month(.abbreviated)
        )
    }

    /// «12 окт 2026»: a milestone's date.
    nonisolated static func date(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted))
    }
}
