import PlayerzAPI
import SwiftUI

/// What an invite is for: nothing private, as the server sends it (no
/// surname, price, other players or booking id).
struct BookingInvitePreviewList: View {
    let preview: Components.Schemas.BookingInvitePreview
    let problem: String?
    let joining: Bool
    let join: () -> Void
    /// «Към моите резервации», for the booker or a player already on it (projectZ#681).
    var openBookings: () -> Void = {}

    var body: some View {
        List {
            Group {
                Section {
                    Text(title)
                        .font(Theme.Typography.cardTitle)
                        .accessibilityAddTraits(.isHeader)
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
                    Section { Text(problem).foregroundStyle(Theme.Palette.danger) }
                }
            }
            .brandListRow()
            // Their own booking, or one they are on already (projectZ#681): no
            // «Включи се», which would only answer that they are on it.
            if let viewer = preview.viewer, viewer.isPlaying {
                Section {
                    Text(String(localized: viewer.isBooker ? "bookingInvite.yours" : "bookingInvite.alreadyOn"))
                        .font(Theme.Typography.rowTitle)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.s)
                    Button(String(localized: "bookingInvite.toMyBookings"), action: openBookings)
                        .buttonStyle(.brandSecondary)
                }
                .bareListRow()
            } else {
            // The screen's one action: the accent pill, on the page.
            Section {
                Button(action: join) {
                    if joining {
                        ProgressView().tint(Theme.Palette.onAccent)
                    } else {
                        Text(String(localized: "bookingInvite.join"))
                    }
                }
                .buttonStyle(.brandPrimary)
                .disabled(joining || preview.spotsLeft == 0)
                // The spinner has no name: the button keeps its own while it turns.
                .accessibilityLabel(String(localized: "bookingInvite.join"))
            } footer: {
                Text(
                    preview.lesson == nil
                        ? String(localized: "bookingInvite.payAtClub")
                        : String(localized: "bookingInvite.lesson.payAtClub")
                )
                .padding(.top, Theme.Spacing.s)
            }
            .bareListRow()
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
