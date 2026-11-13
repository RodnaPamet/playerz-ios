import Combine
import PlayerzAPI
import SwiftUI

/// The player's tabs under the floating bar: «Начало», «Открий», the round
/// «Създай», «Резервации», «Профил». Messages and the bell are in each
/// screen's header (`BrandHeaderActions`), as on the web.
///
/// Not a TabView: its bar cannot be restyled, and hiding it behaves
/// differently from one iOS to the next. Every tab opened so far stays alive
/// behind the selected one, so its stack and scroll position are there on
/// return. `DebugLaunch.Tab` still names the tabs; `.messages` is no longer
/// one of them: the inbox is a layer over the tabs here, not a cover, so the
/// sheets RootView hangs on the shell (a push's screen, an invite, the bell,
/// the phone step) still come up over it.
struct PlayerShell: View {
    @Bindable var session: SessionModel
    @Binding var tab: DebugLaunch.Tab

    /// The tabs opened so far: one never opened loads nothing.
    @State private var mounted: Set<DebugLaunch.Tab> = []
    @State private var creating = DebugLaunch.create
    @State private var chrome = ShellChrome()
    @State private var keyboardUp = false
    @State private var barHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.Palette.page.ignoresSafeArea()
            ForEach(tabs, id: \.self) { item in
                if item == tab || mounted.contains(item) {
                    screen(item)
                        .opacity(item == tab ? 1 : 0)
                        .allowsHitTesting(item == tab)
                        .accessibilityHidden(item != tab || session.messagesOpen)
                        .environment(\.shellTabIsActive, item == tab)
                        .zIndex(item == tab ? 1 : 0)
                }
            }
            if session.messagesOpen {
                InboxView(session: session, unread: $session.messagesUnread)
                    .background(Theme.Palette.page.ignoresSafeArea())
                    .zIndex(2)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: session.messagesOpen)
        // Every page keeps this much clear at its end (`shellBarHeight`):
        // the shell's own inset did not reach through the tabs' stacks.
        .environment(\.shellBarHeight, showsBar ? barHeight : 0)
        .overlay(alignment: .bottom) {
            if showsBar {
                bar.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
            }
        }
        .environment(chrome)
        .onChange(of: tab, initial: true) { _, now in mounted.insert(now) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        .brandSheet(isPresented: $creating) {
            CreateSheet(modules: session.modules, choose: create)
        }
    }

    /// Gone under the keyboard, under a screen that asked (`floatingTabBarHidden`),
    /// and under the inbox.
    private var showsBar: Bool { !keyboardUp && chrome.barHiders == 0 && !session.messagesOpen }

    /// A module the server has off has no tab (#16).
    private var tabs: [DebugLaunch.Tab] {
        session.modules.openPlay ? [.play, .games, .bookings, .profile] : [.play, .bookings, .profile]
    }

    @ViewBuilder private func screen(_ item: DebugLaunch.Tab) -> some View {
        switch item {
        case .play: VenueListView(session: session)
        case .games: GamesView(session: session)
        case .bookings: MyBookingsView(session: session)
        case .profile: ProfileView(session: session)
        case .messages: EmptyView()
        }
    }

    private var bar: some View {
        BrandTabBar(
            selection: $tab,
            leading: [BrandTabItem(id: .play, title: String(localized: "tab.home"), systemImage: "house")]
                + (session.modules.openPlay
                    ? [BrandTabItem(id: .games, title: String(localized: "tab.explore"), systemImage: "magnifyingglass")]
                    : []),
            trailing: [
                BrandTabItem(id: .bookings, title: String(localized: "tab.bookings"), systemImage: "calendar"),
                BrandTabItem(id: .profile, title: String(localized: "tab.profile"), systemImage: "person.crop.circle"),
            ],
            centerLabel: String(localized: "tab.create"),
            onCenter: { creating = true }
        )
    }

    private func create(_ choice: CreateSheet.Choice) {
        creating = false
        switch choice {
        case .court: session.showHome(.clubs)
        // A game is opened from a booking («Търся играчи»), so that is where this goes.
        case .game: tab = .bookings
        case .lesson: session.showHome(.coaches)
        }
    }
}
