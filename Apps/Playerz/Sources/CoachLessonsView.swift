import PlayerzAPI
import SwiftUI

/// «Уроци» (#21): the coach's lessons, upcoming or past. One not yet started
/// can be cancelled (the court is freed, the player told); once it has
/// started, a player who did not come can be marked, which counts at the club
/// like any no-show.
struct CoachLessonsView: View {
    @Bindable var session: SessionModel

    @State private var when: Operations.listMyCoachLessons.Input.Query.whenPayload = .upcoming
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

    var body: some View {
        List {
            Picker(String(localized: "coachLessons.tabsLabel"), selection: $when) {
                Text(String(localized: "coachLessons.tabs.upcoming")).tag(Operations.listMyCoachLessons.Input.Query.whenPayload.upcoming)
                Text(String(localized: "coachLessons.tabs.past")).tag(Operations.listMyCoachLessons.Input.Query.whenPayload.past)
            }
            .pickerStyle(.segmented)
            if let problem {
                Text(problem).foregroundStyle(.red)
            }
            switch phase {
            case .loading:
                ProgressView()
            case .failed:
                Button(String(localized: "coachLessons.retry"), action: retry)
            case .loaded where items.isEmpty:
                Text(when == .upcoming ? String(localized: "coachLessons.noneUpcoming") : String(localized: "coachLessons.nonePast"))
                    .foregroundStyle(.secondary)
            case .loaded:
                ForEach(items, id: \.id) { lesson in
                    Section {
                        CoachLessonRow(lesson: lesson)
                        if canCancel(lesson) {
                            Button(String(localized: "coachLessons.cancel.button"), role: .destructive) {
                                ask(Asked(lesson: lesson, act: .cancel))
                            }
                        }
                        if canMarkNoShow(lesson) {
                            Button(String(localized: "coachLessons.noShow.button")) {
                                ask(Asked(lesson: lesson, act: .noShow))
                            }
                        }
                    }
                    .onAppear {
                        if lesson.id == items.last?.id { Task { await loadMore() } }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "coachLessons.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: when) { await load() }
        .refreshable { await load() }
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
