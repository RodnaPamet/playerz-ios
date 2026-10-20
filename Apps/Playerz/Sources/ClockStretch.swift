import Foundation

/// One stretch of a working day, in minutes after midnight on the venue's clock.
struct ClockStretch: Hashable, Identifiable {
    var open: Int
    var close: Int
    let id = UUID()
}
