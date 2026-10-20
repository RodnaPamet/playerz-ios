import PlayerzAPI
import SwiftUI

/// One lesson: when, where and on which court, the player (with their level,
/// and phone to call), how many play, and the coach's fee.
struct CoachLessonRow: View {
    let lesson: Components.Schemas.MyCoachLesson

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(GameText.when(lesson.startTs, timezone: lesson.venue.timezone)).font(.headline)
            Text(String(localized: "coachLessons.where \(lesson.venue.name) \(lesson.court.name) \(GameText.sport(lesson.court.sport))"))
                .font(.subheadline)
            Text(player).font(.subheadline)
            if lesson.players > 1 {
                Text(String(localized: "coachLessons.group \(lesson.players)")).font(.footnote).foregroundStyle(.secondary)
            }
            Text(String(localized: "coachLessons.fee \(CoachText.money(lesson.coachFeeCents, lesson.currency))"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let phone = lesson.player?.phone, let call = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                Link(phone, destination: call).font(.footnote)
            }
        }
    }

    private var player: String {
        guard let player = lesson.player else { return String(localized: "coachLessons.noPlayer") }
        let name = player.name ?? String(localized: "coachLessons.unnamed")
        if let rating = player.rating {
            let level = rating.level.formatted(.number.precision(.fractionLength(1)))
            return rating.provisional
                ? String(localized: "coachLessons.playerLevelProvisional \(name) \(level)")
                : String(localized: "coachLessons.playerLevel \(name) \(level)")
        }
        if let level = player.level {
            return String(localized: "coachLessons.playerLevel \(name) \(level.formatted())")
        }
        return String(localized: "coachLessons.player \(name)")
    }
}
