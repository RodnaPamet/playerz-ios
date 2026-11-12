import PlayerzAPI
import SwiftUI

/// «Сигнал» to the moderators: a reason and, if they want, a few words.
/// Shared by a message, a conversation (#484) and a coach's review (#19);
/// `send` reports, and answers whether it went.
struct ReportSheet: View {
    let title: String
    let send: (Components.Schemas.ReportRequest.reasonPayload, String) async -> Bool
    let done: () -> Void

    @State private var reason: Components.Schemas.ReportRequest.reasonPayload = .spam
    @State private var details = ""
    @State private var busy = false
    @State private var outcome: (text: String, sent: Bool)?

    var body: some View {
        BrandDarkSheet(title: title, subtitle: String(localized: "messages.reportBody")) {
            Text(String(localized: "messages.reportReason"))
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityAddTraits(.isHeader)
            ForEach(Components.Schemas.ReportRequest.reasonPayload.allCases, id: \.self) { r in
                BrandSheetRow(
                    title: localized(key: "messages.reason.\(r.rawValue)"),
                    systemImage: icon(r),
                    isSelected: reason == r
                ) { reason = r }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(String(localized: "messages.reportDetails"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Palette.onHeader)
                TextField("", text: $details, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundStyle(Theme.Palette.onHeader)
                    .padding(Theme.Spacing.m)
                    .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
                    .accessibilityLabel(String(localized: "messages.reportDetails"))
            }
            .padding(.top, Theme.Spacing.s)
            if let outcome {
                Text(outcome.text)
                    .font(.subheadline)
                    .foregroundStyle(outcome.sent ? Theme.Palette.success : Theme.Palette.danger)
            }
            Button(String(localized: "messages.reportSend"), action: submit)
                .buttonStyle(.brandPrimary)
                .disabled(busy || details.count > 1000)
                .padding(.top, Theme.Spacing.s)
            Button(String(localized: "messages.cancel"), action: done)
                .buttonStyle(.brandSecondary)
        }
        // The dark sheet's chrome (`brandSheet`'s), here: it is presented
        // with a plain `sheet` from a conversation and from a coach's screen.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Palette.sheetSurface)
        .presentationCornerRadius(Theme.Radius.sheet)
        .environment(\.colorScheme, .dark)
        .onChange(of: outcome?.text) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
    }

    /// A picture per reason, for the row's square.
    private func icon(_ reason: Components.Schemas.ReportRequest.reasonPayload) -> String {
        switch reason {
        case .spam: "megaphone"
        case .abuse: "hand.raised"
        case .inappropriate: "eye.slash"
        case .other: "ellipsis.bubble"
        }
    }

    private func submit() {
        Task {
            busy = true
            let sent = await send(reason, details)
            busy = false
            outcome = (
                sent ? String(localized: "messages.reportSent") : String(localized: "messages.reportFailed"),
                sent
            )
            if sent {
                try? await Task.sleep(for: .seconds(1.2))
                done()
            }
        }
    }
}
