/// What a notification is about, for the list's chips: the server's
/// `category` (projectZ#677), which also filters the list.
public enum NotificationCategory: String, CaseIterable, Hashable, Sendable {
    case bookings, games, messages, lessons, tournaments, other

    /// The server's group for a notification (projectZ#677), so a new kind
    /// lands where the server puts it.
    public init(_ item: Components.Schemas.Notification) {
        self = NotificationCategory(rawValue: item.category.rawValue) ?? .other
    }

    /// The chips this server's modules leave (#16): the bell still lists
    /// everything under «Всички», as the web's does.
    public static func chips(_ modules: Modules) -> [NotificationCategory] {
        var chips: [NotificationCategory] = [.bookings]
        if modules.openPlay || modules.ranking { chips.append(.games) }
        if modules.messaging { chips.append(.messages) }
        if modules.coaches { chips.append(.lessons) }
        if modules.ranking { chips.append(.tournaments) }
        return chips
    }
}
