import Foundation

extension SessionModel {
    /// Where a picture the server named is fetched from (`Me.avatarUrl`, a
    /// counterpart's): its own address when it has one, otherwise a path on
    /// the server this session talks to.
    func mediaURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: raw, relativeTo: URL(string: serverURL))?.absoluteURL
    }
}
