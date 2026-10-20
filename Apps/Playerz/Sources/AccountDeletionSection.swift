import PlayerzAPI
import SwiftUI

/// «Изтриване на профила» and «Изтегли моите данни» in Профил (playerz-ios#9).
///
/// App Store guideline 5.1.1(v): an account made in the app can be deleted in
/// the app. The words are the web's (`profile.delete`, `profile.data`), and so
/// is the order: what deletion does, the data to download first, then the
/// button and a typed confirmation.
///
/// The server decides: `DELETE /me` refuses a club account and an account
/// with something still to play, and deletes anything else at once. Until the
/// API says beforehand what stands in the way (projectZ#628), a refusal is
/// shown here after the attempt, and unused credit is stated as a rule.
struct AccountDeletionSection: View {
    /// Where a DEBUG launch scrolls Профил to (`PLAYERZ_PROFILE`).
    static let anchor = "profile.delete"

    @Bindable var session: SessionModel

    @State private var confirming = false
    @State private var outcome: AccountDeletion?
    @State private var exportFile: ExportFile?
    @State private var savingExport = false
    @State private var exporting = false
    @State private var exportProblem: String?
    // VoiceOver is moved to a refusal or a failed download when it appears:
    // otherwise it stays on the button, and the new text above it is never read.
    @AccessibilityFocusState private var outcomeFocused: Bool
    @AccessibilityFocusState private var exportProblemFocused: Bool

    var body: some View {
        Section {
            Text(String(localized: "profile.delete.intro"))
            Text(String(localized: "profile.delete.exportFirst"))
                .foregroundStyle(.secondary)
            Button(action: startExport) {
                HStack {
                    Text(String(localized: "profile.data.download"))
                    if exporting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(exporting)
            // On one row, not the Section: in a Form a Section's modifiers
            // reach every row, and one flag would present once per row.
            .fileExporter(
                isPresented: $savingExport,
                document: exportFile,
                contentType: .json,
                defaultFilename: exportFile?.name
            ) { _ in
                exportFile = nil
            }
            if let exportProblem {
                Text(exportProblem)
                    .foregroundStyle(.red)
                    .accessibilityFocused($exportProblemFocused)
            }

            Text(String(localized: "profile.delete.noShowCarry"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(String(localized: "profile.delete.creditRule"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let outcome {
                DeletionOutcomeView(outcome: outcome, contactForm: session.contactFormURL)
                    .accessibilityElement(children: .contain)
                    .accessibilityFocused($outcomeFocused)
            }

            Button(String(localized: "profile.delete.button"), role: .destructive, action: askToConfirm)
                .id(Self.anchor)
                .sheet(isPresented: $confirming, onDismiss: focusOutcome) {
                    ConfirmDeletionSheet(delete: delete)
                }
                .task(openForDebugLaunch)
        } header: {
            Text(String(localized: "profile.delete.title"))
        }
    }

    private func askToConfirm() {
        confirming = true
    }

    private func delete() async {
        outcome = await session.deleteAccount()
    }

    /// Once the sheet has gone, so VoiceOver does not put focus back on the button.
    private func focusOutcome() {
        if let outcome, outcome != .deleted { outcomeFocused = true }
    }

    /// DEBUG only (`PLAYERZ_PROFILE=confirm`): open the confirmation once
    /// Профил has scrolled here. Nothing is deleted without the typed word.
    private func openForDebugLaunch() async {
        guard DebugLaunch.profile == .confirm else { return }
        try? await Task.sleep(for: .milliseconds(900))
        confirming = true
    }

    private func startExport() {
        // Before the Task: a second tap must find the button already off.
        exporting = true
        Task { await export() }
    }

    private func export() async {
        exportProblem = nil
        defer { exporting = false }
        do {
            exportFile = ExportFile(data: try await session.exportData())
            savingExport = true
        } catch DataExportError.rateLimited {
            exportProblem = String(localized: "profile.data.rateLimited")
            exportProblemFocused = true
        } catch {
            exportProblem = String(localized: "profile.data.failed")
            exportProblemFocused = true
        }
    }
}
