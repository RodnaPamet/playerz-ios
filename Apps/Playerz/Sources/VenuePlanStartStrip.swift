import SwiftUI

/// The plan's starts (#25), time first: every start at which some court on the
/// plan is free, the one showing marked. Scrolls sideways, like the days above.
struct VenuePlanStartStrip: View {
    let starts: [Date]
    let selected: Date?
    @Binding var chosen: Date?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(starts, id: \.self) { start in
                    Button {
                        chosen = start
                    } label: {
                        Text(VenuePlanText.time(start))
                            .font(.subheadline)
                            .monospacedDigit()
                            .padding(.horizontal, 14)
                            // 44 pt, Apple's smallest tap target.
                            .frame(minWidth: 44, minHeight: 44)
                            .background(
                                start == selected ? Color.accentColor.opacity(0.18) : Color.clear,
                                in: Capsule()
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(start == selected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "venuePlan.startTime"))
    }
}
