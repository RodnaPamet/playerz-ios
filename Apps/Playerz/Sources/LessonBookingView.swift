import PlayerzAPI
import SwiftUI

/// «Запишете урок» (playerz-ios#19), as the web's coach page: the venue, the
/// sport and the length, a day of the next 14 at the venue, then a time the
/// coach and a court are both free. The price is for one player: the coach's
/// fee and the court's, paid at the club.
struct LessonBookingView: View {
    let coach: Components.Schemas.PublicCoach
    @Bindable var session: SessionModel

    @State private var linkId: String
    @State private var sport: String
    @State private var minutes: Int
    @State private var day: String
    @State private var times: Components.Schemas.LessonTimes?
    @State private var loading = false
    @State private var problem: String?
    @State private var picked: PickedLessonTime?
    @State private var booked: String?

    init(coach: Components.Schemas.PublicCoach, session: SessionModel) {
        self.coach = coach
        self.session = session
        let first = coach.venues.first
        _linkId = State(initialValue: first?.linkId ?? "")
        _sport = State(initialValue: first?.sports.first ?? "")
        _minutes = State(initialValue: first?.lessonMinutes.first ?? 60)
        let days = first.map { LessonDays.days(from: .now, timezone: $0.timezone) } ?? []
        // A DEBUG launch can open a day ahead (DebugLaunch).
        _day = State(initialValue: days.indices.contains(DebugLaunch.coachBook ?? 0) ? days[DebugLaunch.coachBook ?? 0] : days.first ?? "")
    }

    private var venue: Components.Schemas.PublicCoachVenue? {
        coach.venues.first { $0.linkId == linkId }
    }

    private var days: [String] {
        venue.map { LessonDays.days(from: .now, timezone: $0.timezone) } ?? []
    }

    var body: some View {
        Form {
            if let venue {
                Section {
                    if coach.venues.count > 1 {
                        Picker(String(localized: "coaches.lesson.venueLabel"), selection: $linkId) {
                            ForEach(coach.venues, id: \.linkId) { venue in
                                Text(String(localized: "coaches.lesson.at \(venue.name) \(venue.club.name)")).tag(venue.linkId)
                            }
                        }
                    } else {
                        Text(String(localized: "coaches.lesson.at \(venue.name) \(venue.club.name)"))
                    }
                    if venue.sports.count > 1 {
                        Picker(String(localized: "coaches.lesson.sportLabel"), selection: $sport) {
                            ForEach(venue.sports, id: \.self) { Text(GameText.sport($0)).tag($0) }
                        }
                    }
                    Picker(String(localized: "coaches.lesson.lengthLabel"), selection: $minutes) {
                        ForEach(venue.lessonMinutes, id: \.self) { length in
                            Text(String(localized: "coaches.lesson.minutes \(length)")).tag(length)
                        }
                    }
                    Picker(String(localized: "coaches.lesson.dayLabel"), selection: $day) {
                        ForEach(days, id: \.self) { day in
                            Text(LessonDayText.label(day)).tag(day)
                        }
                    }
                }
                Section {
                    if let problem {
                        Text(problem).foregroundStyle(.red)
                    }
                    if loading && times == nil {
                        ProgressView()
                    } else if let times, times.times.isEmpty {
                        Text(String(localized: "coaches.lesson.none")).foregroundStyle(.secondary)
                    } else if let times {
                        ForEach(times.times, id: \.startTs) { time in
                            Button { pick(time) } label: {
                                LabeledContent(
                                    LessonDayText.time(time.startTs, timezone: times.venue.timezone),
                                    value: CoachText.money(time.totalCents, times.currency)
                                )
                            }
                            .tint(.primary)
                        }
                    }
                } header: {
                    Text(String(localized: "coaches.lesson.timesLabel"))
                } footer: {
                    if let times {
                        Text(String(localized: "coaches.lesson.priceNote \(CoachText.money(times.coachFeeCents, times.currency))"))
                    }
                }
            }
        }
        .navigationTitle(String(localized: "coaches.lesson.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(linkId)|\(sport)|\(minutes)|\(day)") { await loadTimes() }
        .onChange(of: linkId) { _, _ in fitToVenue() }
        .sheet(item: $picked) { picked in
            if let times, let venue {
                LessonConfirmSheet(
                    coachSlug: coach.slug,
                    coachName: CoachText.name(coach.name),
                    venue: venue,
                    times: times,
                    time: picked.time,
                    session: session,
                    booked: lessonBooked,
                    refused: lessonRefused
                )
            }
        }
        .navigationDestination(item: $booked) { id in
            BookingDetailView(bookingId: id, session: session)
        }
    }

    /// Another venue has its own sports, lengths and days: keep what still fits.
    private func fitToVenue() {
        guard let venue else { return }
        if !venue.sports.contains(sport) { sport = venue.sports.first ?? "" }
        if !venue.lessonMinutes.contains(minutes) { minutes = venue.lessonMinutes.first ?? 60 }
        if !days.contains(day) { day = days.first ?? "" }
    }

    private func pick(_ time: Components.Schemas.LessonTime) {
        problem = nil
        picked = PickedLessonTime(time: time)
    }

    private func lessonBooked(_ bookingId: String) {
        picked = nil
        booked = bookingId
    }

    /// A refusal that means the times have moved: say why above them, and read them again.
    private func lessonRefused(_ text: String) {
        picked = nil
        problem = text
        Task { await loadTimes() }
    }

    private func loadTimes() async {
        guard !linkId.isEmpty, !day.isEmpty, let client = await session.client() else { return }
        loading = true
        defer { loading = false }
        let query = Operations.listCoachLessonTimes.Input.Query(
            linkId: linkId, date: day, minutes: minutes, sport: sport.isEmpty ? nil : sport
        )
        if let fresh = try? await client.listCoachLessonTimes(path: .init(slug: coach.slug), query: query).ok.body.json.data {
            times = fresh
        }
    }
}
