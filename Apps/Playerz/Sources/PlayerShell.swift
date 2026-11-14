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
    /// Bumped when a tab's button is tapped: that tab starts again from its
    /// first page (owner 2026-11-14: "clicking a bottom bar menu button
    /// should take the user to the respective page - home included").
    @State private var roots: [DebugLaunch.Tab: Int] = [:]
    /// The screen on show, for the assistant's question (#122).
    @State private var pages = AssistantPageTracker()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.Palette.page.ignoresSafeArea()
            ForEach(tabs, id: \.self) { item in
                if item == tab || mounted.contains(item) {
                    screen(item)
                        .id(roots[item, default: 0])
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
        // «Асистент» (#122), lower right on every screen, above the bar or a
        // screen's own bottom button. Always mounted, only hidden: its sheets
        // hang on it, and the sheet's own keyboard (which also hides the
        // button) must not take the conversation down with it.
        .overlay(alignment: .bottomTrailing) {
            AssistantLauncher(session: session, page: page, shown: session.showsAssistant && !keyboardUp)
                .padding(.trailing, Theme.Spacing.l)
                .padding(.bottom, launcherClearance)
        }
        .environment(chrome)
        .environment(pages)
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

    /// Above the floating bar; above a screen's own bottom bar where the
    /// screen took the floating one away (a game's action, a chat's field).
    private var launcherClearance: CGFloat {
        if showsBar { return barHeight + Theme.Spacing.s }
        return chrome.barHiders > 0 ? 84 : Theme.Spacing.m
    }

    /// The page the assistant is told the person is on: a screen that names
    /// a club, a booking or a game, else the tab's own.
    private var page: AssistantPage {
        if session.messagesOpen { return .init(.messages) }
        if let shown = pages.top { return shown }
        switch tab {
        case .play: return .init(.home)
        case .games: return .init(.games)
        case .bookings: return .init(.bookings)
        case .profile: return .init(.profile)
        case .messages: return .init(.messages)
        }
    }

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
            // A tap on a tab's button, the one on screen or another: that
            // tab on its first page. Links and «Създай» set `tab` directly,
            // so the screen they ask for is kept.
            selection: Binding(get: { tab }, set: { new in
                roots[new, default: 0] += 1
                tab = new
            }),
            leading: [BrandTabItem(id: .play, title: String(localized: "tab.home"), systemImage: "house")]
                + (session.modules.openPlay
                    ? [BrandTabItem(id: .games, title: String(localized: "tab.explore"), systemImage: "magnifyingglass")]
                    : []),
            trailing: [
                BrandTabItem(id: .bookings, title: String(localized: "tab.bookings"), systemImage: "calendar"),
                BrandTabItem(id: .profile, title: String(localized: "tab.profile"), systemImage: "person.crop.circle"),
            ],
            centerLabel: String(localized: "tab.create"),
            onCenter: { creating = true },
            onReselect: { item in roots[item, default: 0] += 1 }
        )
    }

    private func create(_ choice: CreateSheet.Choice) {
        creating = false
        switch choice {
        case .court: session.showHome(.clubs)
        // A new game in one flow (owner 2026-11-13), from «Начало».
        case .game: session.showHome(.newGame)
        case .lesson: session.showHome(.coaches)
        }
    }
}
