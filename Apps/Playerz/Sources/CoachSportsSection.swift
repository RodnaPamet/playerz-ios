import PlayerzAPI
import SwiftUI

/// «Спортове и нива»: each sport the coach teaches, and to players of which
/// levels (1–7). The whole list is saved at once.
struct CoachSportsSection: View {
    @Binding var sports: [Components.Schemas.CoachSportLevels]
    let editable: Bool

    var body: some View {
        Section {
            ForEach($sports, id: \.sport) { $sport in
                CoachSportRow(sport: $sport, editable: editable)
                    .deleteDisabled(!editable)
            }
            .onDelete(perform: remove)
            if editable, !unused.isEmpty {
                Menu(String(localized: "coachProfile.sports.add"), systemImage: "plus") {
                    ForEach(unused, id: \.self) { sport in
                        Button(GameText.sport(sport)) { add(sport) }
                    }
                }
            }
        } header: {
            Text(String(localized: "coachProfile.sports.title"))
        } footer: {
            Text(String(localized: "coachProfile.sports.hint"))
        }
    }

    private var unused: [String] {
        Sports.leveled.filter { sport in !sports.contains { $0.sport == sport } }
    }

    private func add(_ sport: String) {
        sports.append(.init(sport: sport, levelMin: 1, levelMax: 7))
    }

    private func remove(_ offsets: IndexSet) {
        sports.remove(atOffsets: offsets)
    }
}
