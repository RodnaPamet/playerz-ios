import Foundation

/// Time first, then the plan (#25, owner 2026-10-20): the starts the plan
/// offers, and a taken court's next free ones. From the same free slots the
/// screen's list shows, so the plan and the list never disagree.
public enum VenuePlanTimes {
    /// Every start at which at least one court is free, earliest first.
    public static func starts(_ freeByCourt: [[Date]]) -> [Date] {
        Set(freeByCourt.joined()).sorted()
    }

    /// A court's free starts after `start`, at most `limit`.
    public static func later(_ free: [Date], after start: Date, limit: Int = 3) -> [Date] {
        Array(free.filter { $0 > start }.sorted().prefix(limit))
    }
}
