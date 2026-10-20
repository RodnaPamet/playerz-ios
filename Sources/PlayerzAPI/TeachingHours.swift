/// A coach's weekly hours at a venue (playerz-ios#21): stretches of time on
/// each day, on the venue's clock, as `CoachTeachingHours` carries them
/// (`dayOfWeek` 0 = Sunday … 6 = Saturday, `open`/`close` as "H:MM").
public enum TeachingHours {
    /// Minutes after midnight for "9:00" or "21:30"; nil for anything else.
    public static func minutes(_ clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, parts[1].count == 2,
              let hours = Int(parts[0]), let minutes = Int(parts[1]),
              (0...24).contains(hours), (0..<60).contains(minutes)
        else { return nil }
        let total = hours * 60 + minutes
        return total <= 24 * 60 ? total : nil
    }

    /// "9:00" for 540, as the server writes it.
    public static func clock(_ minutes: Int) -> String {
        let shown = String(minutes % 60)
        return "\(minutes / 60):\(shown.count == 1 ? "0" + shown : shown)"
    }

    /// The web's rule for one day: on the quarter hour, each end after its
    /// start, no two overlapping, at most four.
    public static func valid(_ day: [(open: Int, close: Int)]) -> Bool {
        guard day.count <= 4 else { return false }
        let sorted = day.sorted { $0.open < $1.open }
        for (index, stretch) in sorted.enumerated() {
            guard stretch.open % 15 == 0, stretch.close % 15 == 0, stretch.open < stretch.close,
                  stretch.close <= 24 * 60
            else { return false }
            if index > 0, sorted[index - 1].close > stretch.open { return false }
        }
        return true
    }
}
