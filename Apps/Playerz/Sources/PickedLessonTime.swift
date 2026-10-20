import Foundation
import PlayerzAPI

/// A lesson time picked to confirm (#19), for `sheet(item:)`: a start is
/// unique among one day's times.
struct PickedLessonTime: Identifiable {
    let time: Components.Schemas.LessonTime
    var id: Date { time.startTs }
}
