import Foundation

/// The arithmetic behind «Профил» → «Прогрес» (playerz-ios#95), out of the
/// views so it is tested: percentages, the busiest day and hours, a level's
/// change, and the range a level chart shows.
public enum StatsFacts {
    /// A whole percent of `whole`; nil with nothing to divide.
    public static func percent(_ part: Int, of whole: Int) -> Int? {
        guard whole > 0 else { return nil }
        return Int((Double(part) * 100 / Double(whole)).rounded())
    }

    /// The index of the largest count, the first on a tie; nil when all are 0.
    public static func busiest(_ counts: [Int]) -> Int? {
        guard let top = counts.max(), top > 0 else { return nil }
        return counts.firstIndex(of: top)
    }

    /// The first hour of the two hours played most (23 runs into 0); nil
    /// without 24 counts or with nothing played.
    public static func busiestTwoHours(_ hours: [Int]) -> Int? {
        guard hours.count == 24 else { return nil }
        return busiest((0..<24).map { hours[$0] + hours[($0 + 1) % 24] })
    }

    /// The change from `before` to `after`, to two decimals; nil without both.
    public static func change(from before: Double?, to after: Double?) -> Double? {
        guard let before, let after else { return nil }
        return ((after - before) * 100).rounded() / 100
    }

    /// The levels a chart's axis shows: theirs, half a level either side,
    /// on whole levels inside 1–7, and at least one level wide, so a flat
    /// line is not drawn as a cliff.
    public static func levelDomain(_ levels: [Double]) -> ClosedRange<Double> {
        guard let low = levels.min(), let high = levels.max() else { return 1...7 }
        var from = max(1, (low - 0.5).rounded(.down))
        var to = min(7, (high + 0.5).rounded(.up))
        if to - from < 1 {
            if to < 7 { to += 1 } else { from -= 1 }
        }
        return from...to
    }
}
