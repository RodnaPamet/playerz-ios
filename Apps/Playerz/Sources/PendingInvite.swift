/// An invite link's token, waiting to be shown (#14).
struct PendingInvite: Identifiable, Hashable {
    let token: String
    var id: String { token }
}
