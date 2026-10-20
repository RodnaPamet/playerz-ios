import SwiftUI

/// What the plan's fills mean (#25). Hidden from VoiceOver, which hears each
/// court's state in words instead.
struct VenuePlanLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            Label {
                Text(String(localized: "venuePlan.free"))
            } icon: {
                RoundedRectangle(cornerRadius: 3).fill(.green).frame(width: 12, height: 12)
            }
            Label {
                Text(String(localized: "venuePlan.taken"))
            } icon: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.fill.tertiary)
                    .stroke(.secondary, lineWidth: 1)
                    .frame(width: 12, height: 12)
            }
            Label {
                Text(String(localized: "venuePlan.picked"))
            } icon: {
                RoundedRectangle(cornerRadius: 3).fill(Color.accentColor).frame(width: 12, height: 12)
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}
