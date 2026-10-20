import PlayerzAPI
import SwiftUI

/// What a refused deletion says, in the web's words.
struct DeletionOutcomeView: View {
    let outcome: AccountDeletion
    let contactForm: URL?

    var body: some View {
        switch outcome {
        case let .blocked(standing):
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "profile.delete.blocked.title")).font(.headline)
                Text(String(localized: "profile.delete.blocked.body"))
                ForEach(standing.bookings) { booking in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.when(booking.start, booking.end)).bold()
                        Text(Self.cure(booking))
                    }
                    .accessibilityElement(children: .combine)
                }
                if standing.total > standing.bookings.count {
                    Text(String(localized: "profile.delete.blocked.more \(standing.total - standing.bookings.count)"))
                }
                if standing.lessons > 0 {
                    Text(String(localized: "profile.delete.blocked.lessons \(standing.lessons)"))
                }
                if standing.tournaments > 0 {
                    Text(String(localized: "profile.delete.blocked.tournaments \(standing.tournaments)"))
                }
            }
        case .clubAccount:
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "profile.delete.club.title")).font(.headline)
                Text(String(localized: "profile.delete.club.body"))
                if let contactForm {
                    Link(String(localized: "profile.delete.club.contact"), destination: contactForm)
                }
            }
        case .rateLimited:
            Text(String(localized: "profile.delete.error.RATE_LIMITED")).foregroundStyle(.red)
        case .failed:
            Text(String(localized: "profile.delete.error.FAILED")).foregroundStyle(.red)
        case .deleted:
            EmptyView()
        }
    }

    private static func when(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(date: .abbreviated, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    /// The `cure` the server named; an unknown one gets the general sentence above.
    private static func cure(_ booking: UpcomingStanding.Booking) -> String {
        switch booking.cure {
        case "cancel":
            let deadline = (booking.cancellableUntil ?? booking.start)
                .formatted(date: .abbreviated, time: .shortened)
            return String(localized: "profile.delete.blocked.cancel \(deadline)")
        case "leave":
            return String(localized: "profile.delete.blocked.leave")
        case "wait":
            let end = (booking.deletableFrom ?? booking.end).formatted(date: .abbreviated, time: .shortened)
            return String(localized: "profile.delete.blocked.wait \(end)")
        default:
            return String(localized: "profile.delete.blocked.body")
        }
    }
}
