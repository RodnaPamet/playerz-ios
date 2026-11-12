import SwiftUI

/// What a screen can ask of the shell around the tabs: today, to take the
/// floating bar away while it is on screen.
@MainActor
@Observable
final class ShellChrome {
    /// How many screens on show want the bar gone; it is hidden above zero.
    private(set) var barHiders = 0

    func hideBar() { barHiders += 1 }
    func showBar() { barHiders = max(0, barHiders - 1) }
}

private struct ShellTabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether this screen's tab is the one on show. Every tab stays alive
    /// behind the selected one, so `onAppear` and `task` run ONCE, not on each
    /// return as under the system's TabView.
    var shellTabIsActive: Bool {
        get { self[ShellTabIsActiveKey.self] }
        set { self[ShellTabIsActiveKey.self] = newValue }
    }
}

private struct ShellTabReturn: ViewModifier {
    let action: @MainActor () async -> Void
    @Environment(\.shellTabIsActive) private var active

    func body(content: Content) -> some View {
        content.onChange(of: active) { _, now in
            if now { Task { await action() } }
        }
    }
}

private struct FloatingTabBarHidden: ViewModifier {
    // Optional: a sheet or a preview has no shell around it.
    @Environment(ShellChrome.self) private var chrome: ShellChrome?
    @Environment(\.shellTabIsActive) private var active
    @State private var onScreen = false
    @State private var holding = false

    // A hide is held only while this screen's tab is the one on show: a tab
    // left behind stays mounted and gets no `onDisappear`, and its hide would
    // take the bar from the tab switched to.
    func body(content: Content) -> some View {
        content
            .onAppear {
                onScreen = true
                hold(active)
            }
            .onDisappear {
                onScreen = false
                hold(false)
            }
            .onChange(of: active) { _, now in hold(onScreen && now) }
    }

    private func hold(_ wanted: Bool) {
        guard wanted != holding else { return }
        holding = wanted
        if wanted { chrome?.hideBar() } else { chrome?.showBar() }
    }
}

extension View {
    /// Runs each time the user comes BACK to this screen's tab: what a tab's
    /// first screen reloads, now that `task` no longer runs again by itself.
    func onShellTabReturn(_ action: @escaping @MainActor () async -> Void) -> some View {
        modifier(ShellTabReturn(action: action))
    }

    /// No floating bar while this screen is on show: a pushed screen with its
    /// own bottom button, a full-screen map.
    func floatingTabBarHidden() -> some View {
        modifier(FloatingTabBarHidden())
    }
}
