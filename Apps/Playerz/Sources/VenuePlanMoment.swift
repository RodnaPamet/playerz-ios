import Foundation
import PlayerzAPI

/// The plan at one start (#25), worked out once per render: which starts
/// some court on the plan is free at, the one showing, and each court's slot
/// then. From the screen's own free slots, so the plan and the list below
/// never disagree.
struct VenuePlanMoment {
    enum Look { case free, taken, picked }

    /// The courts on the plan, as the list has them for the day.
    let courts: [VenueDetailModel.Court]
    let starts: [Date]
    /// The start chosen, or the first while that one is gone (another day, or booked).
    let start: Date?
    let picked: String?

    init(drawing: VenuePlanDrawing, courts: [VenueDetailModel.Court], chosen: Date?, picked: String?) {
        let ids = Set(drawing.courts.map(\.id))
        let onPlan = courts.filter { ids.contains($0.resourceId) }
        let starts = VenuePlanTimes.starts(onPlan.map { $0.bookable.map(\.startTs) })
        self.courts = onPlan
        self.starts = starts
        start = chosen.flatMap { starts.contains($0) ? $0 : nil } ?? starts.first
        self.picked = picked
    }

    func court(_ id: String?) -> VenueDetailModel.Court? {
        courts.first { $0.resourceId == id }
    }

    /// The court's slot at the start showing, if it is free then.
    func slot(_ court: VenueDetailModel.Court) -> Components.Schemas.AvailabilitySlot? {
        guard let start else { return nil }
        return court.bookable.first { $0.startTs == start }
    }

    func look(_ id: String) -> Look {
        guard let court = court(id), slot(court) != nil else { return .taken }
        return id == picked ? .picked : .free
    }

    /// What VoiceOver says for a court on the plan: its name and its state.
    func describe(_ court: VenuePlanDrawing.Court) -> String {
        guard let start else { return court.name }
        let time = VenuePlanText.time(start)
        switch look(court.id) {
        case .free: return String(localized: "venuePlan.state.free \(court.name) \(time)")
        case .taken: return String(localized: "venuePlan.state.taken \(court.name) \(time)")
        case .picked: return String(localized: "venuePlan.state.picked \(court.name) \(time)")
        }
    }
}
