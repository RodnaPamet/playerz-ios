import PlayerzAPI
import SwiftUI

/// «Уроци» (#21): the coach's lessons, upcoming or past. One not yet started
/// can be cancelled (the court is freed, the player told); once it has
/// started, a player who did not come can be marked, which counts at the club
/// like any no-show.
struct CoachLessonsView: View {
    @Bindable var session: SessionModel

    @State private var when: When = .upcoming
    @State private var items: [Components.Schemas.MyCoachLesson] = []
    @State private var nextCursor: String?
    @State private var phase: Phase = .loading
    @State private var asking: Asked?
    @State private var confirming = false
    @State private var problem: String?

    enum Phase { case loading, loaded, failed }

    /// A cancel or a no-show waiting for its confirmation.
    struct Asked: Identifiable {
        enum Act { case cancel, noShow }
        let lesson: Components.Schemas.MyCoachLesson
        let act: Act
        var id: String { lesson.id }
    }

    private typealias When = Operations.listMyCoachLessons.Input.Query.whenPayload

    var body: some View {
        content
            .brandPage()
            // Hidden with the system bar; still what VoiceOver calls the screen.
            .navigationTitle(String(localized: "coachLessons.title"))
            // «Предстоящи» / «Минали» as the player's bookings have them.
            .brandChipBar {
                BrandChipRow {
                    BrandChip(String(localized: "coachLessons.tabs.upcoming"), isSelected: when == .upcoming) { when = .upcoming }
                    BrandChip(String(localized: "coachLessons.tabs.past"), isSelected: when == .past) { when = .past }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "coachLessons.tabsLabel"))
            }
            .brandHeader(.back(String(localized: "coachLessons.title")))
            .task(id: when) { await load() }
            .onChange(of: problem) { _, text in
                // Said at once: the card that says it may be above the one tapped.
                if let text { AccessibilityNotification.Announcement(text).post() }
            }
            .confirmationDialog(
                asking.map(title) ?? "",
                isPresented: $confirming,
                titleVisibility: .visible,
                presenting: asking
            ) { asked in
                Button(asked.act == .cancel ? String(localized: "coachLessons.cancel.yes") : String(localized: "coachLessons.noShow.yes"),
                       role: .destructive) { act(asked) }
                Button(String(localized: "coachLessons.keep"), role: .cancel) {}
            } message: { asked in
                Text(message(asked))
            }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "coachLessons.failed")) {
                Button(String(localized: "coachLessons.retry"), action: retry)
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where items.isEmpty:
            BrandEmptyState(
                systemImage: "calendar",
                title: when == .upcoming ? String(localized: "coachLessons.noneUpcoming") : String(localized: "coachLessons.nonePast")
            )
            .refreshable { await load() }
        case .loaded:
            // Cards on the page: each lesson is its own, with its own actions.
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.l) {
                    if let problem {
                        BrandContentCard {
                            Label(problem, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Theme.Palette.danger)
                        }
                    }
                    ForEach(items, id: \.id) { lesson in
                        card(lesson)
                            .onAppear {
                                if lesson.id == items.last?.id { Task { await loadMore() } }
                            }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .refreshable { await load() }
        }
    }

    /// One lesson, and under a hairline what can be done about it.
    private func card(_ lesson: Components.Schemas.MyCoachLesson) -> some View {
        let cancels = canCancel(lesson)
        let marks = canMarkNoShow(lesson)
        return VStack(alignment: .leading, spacing: 0) {
            CoachLessonRow(lesson: lesson)
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            if cancels || marks {
                Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
                VStack(alignment: .leading, spacing: 0) {
                    if marks {
                        cardAction(String(localized: "coachLessons.noShow.button"), color: Theme.Palette.accentText) {
                            ask(Asked(lesson: lesson, act: .noShow))
                        }
                    }
                    if cancels {
                        cardAction(String(localized: "coachLessons.cancel.button"), color: Theme.Palette.danger) {
                            ask(Asked(lesson: lesson, act: .cancel))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .brandCardSurface()
    }

    private func cardAction(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func ask(_ asked: Asked) {
        asking = asked
        confirming = true
    }

    private func canCancel(_ lesson: Components.Schemas.MyCoachLesson) -> Bool {
        ["CONFIRMED", "PENDING"].contains(lesson.status) && lesson.startTs > .now
    }

    private func canMarkNoShow(_ lesson: Components.Schemas.MyCoachLesson) -> Bool {
        lesson.startTs <= .now && ["CONFIRMED", "COMPLETED"].contains(lesson.status)
    }

    private func title(_ asked: Asked) -> String {
        asked.act == .cancel ? String(localized: "coachLessons.cancel.title") : String(localized: "coachLessons.noShow.title")
    }

    private func message(_ asked: Asked) -> String {
        let lesson = asked.lesson
        switch asked.act {
        case .cancel:
            let zone = TimeZone(identifier: lesson.venue.timezone) ?? .current
            let day = lesson.startTs.formatted(Date.FormatStyle(timeZone: zone).weekday(.wide).day().month(.wide))
            let time = LessonDayText.time(lesson.startTs, timezone: lesson.venue.timezone)
            return String(localized: "coachLessons.cancel.description \(day) \(time) \(lesson.venue.name)")
        case .noShow:
            let name = lesson.player?.name ?? String(localized: "coachLessons.unnamed")
            return String(localized: "coachLessons.noShow.description \(name) \(lesson.club)")
        }
    }

    private func retry() {
        phase = .loading
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client.listMyCoachLessons(query: .init(when: when)).ok.body.json.data
            items = page.items
            nextCursor = page.nextCursor
            phase = .loaded
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        if let page = try? await client.listMyCoachLessons(query: .init(when: when, cursor: cursor)).ok.body.json.data {
            items += page.items
            nextCursor = page.nextCursor
        }
    }

    private func act(_ asked: Asked) {
        problem = nil
        Task {
            guard let client = await session.client() else { return }
            let error: Components.Schemas._Error.errorPayload?
            switch asked.act {
            case .cancel:
                let response = try? await client.cancelMyCoachLesson(path: .init(id: asked.lesson.id), body: .json(.init()))
                if case .ok? = response { await load(); return }
                error = response.flatMap { apiError($0) }
            case .noShow:
                let response = try? await client.markMyCoachLessonNoShow(path: .init(id: asked.lesson.id))
                if case .ok? = response { await load(); return }
                error = response.flatMap { apiError($0) }
            }
            problem = CoachLessonText.error(error)
        }
    }
}
