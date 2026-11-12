import PlayerzAPI

/// What a notification is about, for the list's chips. The server sends a
/// `kind` per notification and no grouping of its own, so the groups are
/// read off the kind's name: a kind added later with a known prefix
/// (`BOOKING_…`) lands in its group, anything else is only under «Всички».
enum NotificationCategory: String, CaseIterable, Hashable {
    case bookings, games, messages, lessons, tournaments, other

    init(kind: String) {
        if kind == "MESSAGE_RECEIVED" || kind == "CONTACT_REQUEST" {
            self = .messages
        } else if kind.hasPrefix("TOURNAMENT_") {
            self = .tournaments
        } else if kind.hasPrefix("OPEN_PLAY_") || kind.hasPrefix("RESULT_") || kind == "MATCH_RESULT" {
            self = .games
        } else if kind.hasPrefix("LESSON_") || kind.hasPrefix("COACH_") {
            self = .lessons
        } else if kind.hasPrefix("BOOKING_") || ["SESSION_FULL", "PAYMENT_RECEIVED", "SPLIT_REQUESTED"].contains(kind) {
            self = .bookings
        } else {
            self = .other
        }
    }

    /// The chip's word; `other` has no chip.
    var label: String {
        localized(key: "notifications.filter.\(rawValue)")
    }

    var systemImage: String {
        switch self {
        case .bookings: "calendar"
        case .games: "person.3"
        case .messages: "bubble.left"
        case .lessons: "graduationcap"
        case .tournaments: "trophy"
        case .other: "bell"
        }
    }

    /// The chips this server's modules leave (#16): the bell still lists
    /// everything under «Всички», as the web's does.
    static func chips(_ modules: Modules) -> [NotificationCategory] {
        var chips: [NotificationCategory] = [.bookings]
        if modules.openPlay || modules.ranking { chips.append(.games) }
        if modules.messaging { chips.append(.messages) }
        if modules.coaches { chips.append(.lessons) }
        if modules.ranking { chips.append(.tournaments) }
        return chips
    }
}
