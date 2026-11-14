import PlayerzAPI
import SwiftUI

/// Which screen the person is on, for the question's `page`: a screen that
/// names one thing (a club, a booking, a game) says so while it is on show
/// (`assistantPage(_:)`); otherwise the tab's own page stands.
///
/// Every tab stays alive behind the one on show, so a screen counts only
/// while its tab is active, as `floatingTabBarHidden` holds the bar.
@MainActor
@Observable
final class AssistantPageTracker {
    private var shown: [(id: UUID, page: AssistantPage)] = []

    /// The screen most recently put on show.
    var top: AssistantPage? { shown.last?.page }

    func show(_ id: UUID, _ page: AssistantPage) {
        shown.removeAll { $0.id == id }
        shown.append((id, page))
    }

    func hide(_ id: UUID) {
        shown.removeAll { $0.id == id }
    }
}

private struct AssistantPageModifier: ViewModifier {
    let page: AssistantPage
    // Optional: a sheet or a preview has no shell around it.
    @Environment(AssistantPageTracker.self) private var tracker: AssistantPageTracker?
    @Environment(\.shellTabIsActive) private var active
    @State private var id = UUID()
    @State private var onScreen = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                onScreen = true
                update()
            }
            .onDisappear {
                onScreen = false
                update()
            }
            .onChange(of: active) { update() }
            .onChange(of: page) { update() }
    }

    private func update() {
        if onScreen, active { tracker?.show(id, page) } else { tracker?.hide(id) }
    }
}

extension View {
    /// This screen, for the assistant's question while it is on show:
    /// identifiers only (`AssistantPage`).
    func assistantPage(_ page: AssistantPage) -> some View {
        modifier(AssistantPageModifier(page: page))
    }
}
