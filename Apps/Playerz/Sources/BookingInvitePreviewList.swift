import PlayerzAPI
import SwiftUI

/// What an invite is for: nothing private, as the server sends it (no
/// surname, price, other players or booking id).
struct BookingInvitePreviewList: View {
    let preview: Components.Schemas.BookingInvitePreview
    let problem: String?
    let joining: Bool
    let join: () -> Void

    var body: some View {
        List {
            Section {
                Text(title).font(.title3.bold())
                if let lesson = preview.lesson {
                    LabeledContent(
                        String(localized: "bookingInvite.lesson.label"),
                        value: lesson.coach ?? String(localized: "bookingInvite.lesson.noName")
                    )
                }
                LabeledContent(String(localized: "bookingInvite.when")) {
                    Text(GameText.when(preview.startTs, timezone: preview.venue.timezone))
                }
                LabeledContent(String(localized: "bookingInvite.where"), value: "\(preview.venue.name), \(preview.venue.city)")
                LabeledContent(courtLabel, value: preview.resource.name)
            } footer: {
                Text(String(localized: "bookingInvite.spotsLeft \(preview.spotsLeft)"))
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            Section {
                Button(action: join) {
                    if joining { ProgressView() } else { Text(String(localized: "bookingInvite.join")) }
                }
                .disabled(joining || preview.spotsLeft == 0)
            } footer: {
                Text(
                    preview.lesson == nil
                        ? String(localized: "bookingInvite.payAtClub")
                        : String(localized: "bookingInvite.lesson.payAtClub")
                )
            }
        }
    }

    private var title: String {
        guard let name = preview.bookerFirstName else { return String(localized: "bookingInvite.titleNoName") }
        return String(localized: "bookingInvite.title \(name)")
    }

    /// The web's noun for the resource (resource-kinds.ts); a type added later
    /// reads as a court.
    private var courtLabel: String {
        switch preview.resource.resourceType {
        case "FIELD": String(localized: "bookingInvite.pitch.court")
        case "TABLE", "BOARD_TABLE": String(localized: "bookingInvite.table.court")
        case "LOBBY": String(localized: "bookingInvite.seat.court")
        case "TRACK": String(localized: "bookingInvite.track.court")
        default: String(localized: "bookingInvite.court")
        }
    }
}
