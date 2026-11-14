import PlayerzAPI
import SwiftUI

/// A sport's fact of the week (owner 2026-11-13: "keep only 1 fun fact of the
/// week"), read once a week: it changes on Monday at midnight Sofia time.
@MainActor
final class SportFacts {
    static let shared = SportFacts()

    /// By sport and language, with the Sofia Monday its week starts on.
    private var kept: [String: Components.Schemas.SportFactOfTheWeek] = [:]

    func fact(_ sport: String, session: SessionModel) async -> Components.Schemas.SportFactOfTheWeek? {
        let language = AppLanguageChoice.current
        let key = "\(sport)|\(language.rawValue)"
        if let kept = kept[key], kept.fact.weekStart == Self.thisMonday { return kept }
        guard let client = await session.client(),
              let read = try? await client.getSportFact(
                  path: .init(sport: sport),
                  query: .init(locale: language == .en ? .en : .bg)
              ).ok.body.json.data
        else { return kept[key] }
        kept[key] = read
        return read
    }

    /// «2026-11-16», this week's Monday in Sofia: the server's `weekStart`.
    private static var thisMonday: String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/Sofia") ?? .current
        let monday = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let parts = calendar.dateComponents([.year, .month, .day], from: monday)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// «Факт на седмицата» on a sport's page. Nothing while it loads, or for a
/// sport without facts.
struct SportStoryCard: View {
    let sport: String
    let session: SessionModel

    @State private var read: Components.Schemas.SportFactOfTheWeek?

    var body: some View {
        Group {
            if let read {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(String(localized: "story.fact.title"), systemImage: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.accentText)
                        Spacer(minLength: Theme.Spacing.s)
                        Text(String(localized: "story.fact.number \(read.fact.number)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Text(read.fact.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCardSurface()
                .accessibilityElement(children: .combine)
            }
        }
        .task(id: sport) { read = await SportFacts.shared.fact(sport, session: session) }
    }
}
