import Foundation

/// A screen of the app named by a web path (playerz-ios#15).
///
/// A notification's `href` and a push's `url` are paths on the web
/// (`/me/bookings/{id}`, `/messages/{id}`, `/games?tab=mine`): the server
/// writes one link for every client, and sets `refType` on only some kinds.
/// So the app routes on the path. A path with no screen in the app yet (a
/// tournament, a coach's page, a club's own admin) is nil: the row still
/// shows, and opens nothing.
public enum AppLink: Hashable, Sendable, Identifiable {
    case booking(String)
    case conversation(String)
    case bookings
    case messages
    case games(mine: Bool)

    public var id: Self { self }

    /// `path` as the server writes it: a path, or an absolute URL on the site.
    public init?(path: String) {
        guard let parts = URLComponents(string: path) else { return nil }
        let segments = parts.path.split(separator: "/").map(String.init)
        let tab = parts.queryItems?.first { $0.name == "tab" }?.value
        switch segments.count {
        case 1 where segments[0] == "messages": self = .messages
        case 1 where segments[0] == "games": self = .games(mine: tab == "mine")
        case 2 where segments == ["me", "bookings"]: self = .bookings
        case 2 where segments[0] == "messages": self = .conversation(segments[1])
        case 3 where segments[0] == "me" && segments[1] == "bookings": self = .booking(segments[2])
        default: return nil
        }
    }

    /// A notification's link: its `href`, else its `refType` and `refId`.
    public init?(href: String?, refType: String?, refId: String?) {
        if let href, let link = AppLink(path: href) {
            self = link
            return
        }
        switch (refType, refId) {
        case let ("booking", id?): self = .booking(id)
        case let ("conversation", id?): self = .conversation(id)
        default: return nil
        }
    }
}
