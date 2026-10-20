import Foundation

/// A link that adds whoever opens it to a booking (playerz-ios#14):
/// `{site}/invite/booking/{token}`, as `createBookingInviteLink` hands it to
/// the share sheet. The token goes to the server in a request BODY, never a
/// path, so it never lands in a log line.
public enum BookingInviteLink {
    /// The token in `url`, or nil when the URL is not an invite link.
    public static func token(in url: URL) -> String? {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        let parts = url.pathComponents
        guard parts.count == 4, parts[1] == "invite", parts[2] == "booking" else { return nil }
        let token = parts[3]
        // The server's limit; a real one is 43 base64url characters.
        guard !token.isEmpty, token.count <= 200 else { return nil }
        return token
    }
}
