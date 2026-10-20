import PlayerzAPI
import SwiftUI

/// One sport: from which level to which.
struct CoachSportRow: View {
    @Binding var sport: Components.Schemas.CoachSportLevels
    let editable: Bool

    var body: some View {
        let name = GameText.sport(sport.sport)
        VStack(alignment: .leading) {
            Text(name).font(.headline)
            if editable {
                Picker(String(localized: "coachProfile.sports.from"), selection: $sport.levelMin) {
                    ForEach(1...7, id: \.self) { Text($0.formatted()).tag($0) }
                }
                .accessibilityLabel(String(localized: "coachProfile.sports.fromLabel \(name)"))
                Picker(String(localized: "coachProfile.sports.to"), selection: $sport.levelMax) {
                    ForEach(sport.levelMin...7, id: \.self) { Text($0.formatted()).tag($0) }
                }
                .accessibilityLabel(String(localized: "coachProfile.sports.toLabel \(name)"))
            } else {
                Text(sport.levelMin == sport.levelMax
                    ? String(localized: "coachProfile.sports.one \(sport.levelMin)")
                    : String(localized: "coachProfile.sports.range \(sport.levelMin) \(sport.levelMax)"))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: sport.levelMin) { _, low in
            if sport.levelMax < low { sport.levelMax = low }
        }
    }
}
