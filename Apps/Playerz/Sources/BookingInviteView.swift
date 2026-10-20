import PlayerzAPI
import SwiftUI

/// An invite link, opened (playerz-ios#14), as the web's
/// `/invite/booking/{token}`: who invites, when and where, the places left;
/// «Включи се» adds the caller and opens the booking. Payment stays at the club.
struct BookingInviteView: View {
    let token: String
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var preview: Components.Schemas.BookingInvitePreview?
    @State private var invalid = false
    @State private var joining = false
    @State private var problem: String?
    @State private var joined: String?
    /// A `PHONE_REQUIRED` refusal (#11). The phone step opens over this sheet,
    /// not from the root as elsewhere: one sheet cannot present another.
    @State private var phoneStep = false

    var body: some View {
        NavigationStack {
            Group {
                if let preview {
                    BookingInvitePreviewList(
                        preview: preview,
                        problem: problem,
                        joining: joining,
                        join: join
                    )
                } else if invalid {
                    ContentUnavailableView(
                        String(localized: "bookingInvite.invalid.title"),
                        systemImage: "link",
                        description: Text(String(localized: "bookingInvite.invalid.description"))
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "bookingInvite.titleNoName"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close"), action: close)
                }
            }
            .navigationDestination(item: $joined) { id in
                BookingDetailView(bookingId: id, session: session)
            }
            .sheet(isPresented: $phoneStep) {
                PhoneStepView(session: session, confirmed: phoneConfirmed, later: closePhoneStep)
            }
            .task { await load() }
        }
    }

    private func close() {
        dismiss()
    }

    private func load() async {
        guard let client = await session.client() else {
            invalid = true
            return
        }
        let response = try? await client.previewBookingInvite(body: .json(.init(token: token)))
        if case let .ok(ok) = response, let found = try? ok.body.json.data {
            preview = found
            if found.spotsLeft == 0 { problem = BookingPlayerText.joinError("BOOKING_FULL") }
        } else if case .tooManyRequests = response {
            problem = BookingPlayerText.joinError("RATE_LIMITED")
            invalid = true
        } else {
            invalid = true
        }
    }

    private func join() {
        joining = true
        problem = nil
        Task {
            defer { joining = false }
            guard let client = await session.client() else { return }
            let response = try? await client.acceptBookingInvite(body: .json(.init(token: token)))
            if case let .ok(ok) = response, let accepted = try? ok.body.json.data {
                // Joined, or already on it: either way the booking is theirs to see.
                joined = accepted.bookingId
            } else if case .tooManyRequests = response {
                problem = BookingPlayerText.joinError("RATE_LIMITED")
            } else {
                let code = response.flatMap { apiErrorCode($0) }
                problem = BookingPlayerText.joinError(code)
                if code == "PHONE_REQUIRED" { phoneStep = true }
            }
        }
    }

    /// The number is confirmed: join, as the tap meant.
    private func phoneConfirmed() {
        phoneStep = false
        join()
    }

    private func closePhoneStep() {
        phoneStep = false
    }
}
