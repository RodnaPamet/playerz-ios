import PlayerzAPI
import SwiftUI

/// One day's working hours at a venue: its stretches, on the quarter hour, or
/// «не работя».
struct CoachDayHours: View {
    let day: Int
    @Binding var stretches: [ClockStretch]

    /// Every quarter hour of the day, 0:00 to 24:00.
    private static let quarters = Array(stride(from: 0, through: 24 * 60, by: 15))

    var body: some View {
        let name = CoachVenueText.day(day)
        VStack(alignment: .leading) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                if stretches.isEmpty {
                    Text(String(localized: "coachVenues.terms.dayOff")).foregroundStyle(.secondary)
                }
            }
            ForEach($stretches) { $stretch in
                let number = (stretches.firstIndex { $0.id == stretch.id } ?? 0) + 1
                HStack {
                    Picker(String(localized: "coachVenues.terms.fromLabel \(name) \(number)"), selection: $stretch.open) {
                        ForEach(Self.quarters, id: \.self) { Text(TeachingHours.clock($0)).tag($0) }
                    }
                    .labelsHidden()
                    Text(verbatim: "–")
                    Picker(String(localized: "coachVenues.terms.toLabel \(name) \(number)"), selection: $stretch.close) {
                        ForEach(Self.quarters, id: \.self) { Text(TeachingHours.clock($0)).tag($0) }
                    }
                    .labelsHidden()
                    Spacer()
                    Button(String(localized: "coachVenues.terms.removeStretch"), systemImage: "minus.circle", role: .destructive) {
                        remove(stretch)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
            if stretches.count < 4 {
                Button(String(localized: "coachVenues.terms.addStretch"), systemImage: "plus", action: add)
                    .buttonStyle(.borderless)
            }
        }
    }

    private func add() {
        let start = stretches.map(\.close).max() ?? 9 * 60
        stretches.append(ClockStretch(open: min(start, 23 * 60), close: min(start + 3 * 60, 24 * 60)))
    }

    private func remove(_ stretch: ClockStretch) {
        stretches.removeAll { $0.id == stretch.id }
    }
}
