import PlayerzAPI
import SwiftUI

/// The venue plan above the courts (#25), as on the web: time first, then
/// which courts are free for it. Tap a free court and book it under the plan;
/// tap a taken one for its next free times. The court tapped is also the one
/// whose times the list below shows (owner 2026-11-13).
struct VenuePlanSection: View {
    let drawing: VenuePlanDrawing
    let courts: [VenueDetailModel.Court]
    /// The slot being booked, from the screen's model.
    let busySlot: Date?
    let book: (VenueDetailModel.Court, Components.Schemas.AvailabilitySlot) -> Void

    /// The court chosen: the screen's, shared with the list of times.
    @Binding var picked: String?
    @State private var chosen: Date?

    private static let copyright = URL(string: "https://www.openstreetmap.org/copyright")

    var body: some View {
        let moment = VenuePlanMoment(drawing: drawing, courts: courts, chosen: chosen, picked: picked)
        Section {
            if moment.starts.isEmpty {
                Text(String(localized: "venue.noSlots")).foregroundStyle(.secondary)
            } else {
                VenuePlanStartStrip(starts: moment.starts, selected: moment.start, chosen: $chosen)
            }
            VenuePlanCanvas(drawing: drawing, look: moment.look, describe: moment.describe, choose: choose)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            VenuePlanLegend()
            if let court = moment.court(picked), let start = moment.start {
                VenuePlanChoice(
                    court: court,
                    start: start,
                    slot: moment.slot(court),
                    busySlot: busySlot,
                    book: { book(court, $0) },
                    chosen: $chosen
                )
            } else if !moment.starts.isEmpty {
                Text(String(localized: "venuePlan.hint")).foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "venuePlan.title"))
        } footer: {
            // ODbL: «© OpenStreetMap contributors» wherever its shapes show.
            if drawing.creditsOpenStreetMap, let copyright = Self.copyright {
                Link(String(localized: "venuePlan.credit"), destination: copyright)
            }
        }
    }

    private func choose(_ court: String) {
        picked = court
    }
}
