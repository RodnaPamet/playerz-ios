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
    @State private var outcome: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "messages.reportBody"))
                }
                Picker(String(localized: "messages.reportReason"), selection: $reason) {
                    ForEach(Components.Schemas.ReportRequest.reasonPayload.allCases, id: \.self) { r in
                        Text(localized(key: "messages.reason.\(r.rawValue)")).tag(r)
                    }
                }
                Section(String(localized: "messages.reportDetails")) {
                    TextField("", text: $details, axis: .vertical).lineLimit(3...6)
                }
                if let outcome {
                    Section { Text(outcome) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "messages.cancel"), action: done)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "messages.reportSend"), action: submit)
                        .disabled(busy || details.count > 1000)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        Task {
            busy = true
            let sent = await send(reason, details)
            busy = false
            outcome = sent
                ? String(localized: "messages.reportSent")
                : String(localized: "messages.reportFailed")
            if sent {
                try? await Task.sleep(for: .seconds(1.2))
                done()
            }
        }
    }
}
