import PlayerzAPI

extension NotificationCategory {
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
}
