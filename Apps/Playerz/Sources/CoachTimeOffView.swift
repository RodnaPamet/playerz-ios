import PlayerzAPI
import SwiftUI

/// «Почивни дни» (#21): days the coach teaches nowhere. Only they see them.
/// One day, or a span of up to 92 days, with a note if they want.
struct CoachTimeOffView: View {
    @Bindable var session: SessionModel

    @State private var items: [Components.Schemas.CoachTimeOff] = []
    @State private var start = Date.now
    @State private var hasEnd = false
    @State private var end = Date.now
    @State private var note = ""
    @State private var busy = false
    @State private var problem: String?

    var body: some View {
        Form {
            Section {
                if items.isEmpty {
                    Text(String(localized: "coachVenues.timeOff.none")).foregroundStyle(.secondary)
                }
                ForEach(items, id: \.id) { off in
                    VStack(alignment: .leading) {
                        Text(span(off))
                        if let note = off.note, !note.isEmpty {
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(String(localized: "coachVenues.timeOff.remove"), role: .destructive) { remove(off) }
                    }
                    .accessibilityActions {
                        Button(String(localized: "coachVenues.timeOff.remove")) { remove(off) }
                    }
                }
            } footer: {
                Text(String(localized: "coachVenues.timeOff.hint"))
            }
            Section {
                DatePicker(String(localized: "coachVenues.timeOff.start"), selection: $start, displayedComponents: .date)
                Toggle(String(localized: "coachVenues.timeOff.end"), isOn: $hasEnd)
                if hasEnd {
                    DatePicker(String(localized: "coachVenues.timeOff.end"), selection: $end, in: start..., displayedComponents: .date)
                }
                TextField(String(localized: "coachVenues.timeOff.note"), text: $note)
                Button(String(localized: "coachVenues.timeOff.add"), action: add)
                    .disabled(busy || note.count > 200)
            } footer: {
                if let problem { Text(problem).foregroundStyle(.red) }
            }
        }
        .navigationTitle(String(localized: "coachVenues.timeOff.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// «24 окт. – 2 ное.», or one day.
    private func span(_ off: Components.Schemas.CoachTimeOff) -> String {
        let first = LessonDayText.label(off.startDate)
        guard off.endDate != off.startDate else { return String(localized: "coachVenues.timeOff.one \(first)") }
        return String(localized: "coachVenues.timeOff.range \(first) \(LessonDayText.label(off.endDate))")
    }

    /// `YYYY-MM-DD` for a date picked on this phone's calendar.
    private static func day(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func load() async {
        guard let client = await session.client() else { return }
        if let fresh = try? await client.listMyCoachTimeOff().ok.body.json.data { items = fresh.items }
    }

    private func add() {
        busy = true
        problem = nil
        let request = Components.Schemas.AddCoachTimeOffRequest(
            startDate: Self.day(start),
            endDate: hasEnd ? Self.day(end) : nil,
            note: note.isEmpty ? nil : note
        )
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.addMyCoachTimeOff(body: .json(request))
            if case let .created(created)? = response, let fresh = try? created.body.json.data {
                items = fresh.items
                note = ""
                hasEnd = false
            } else {
                problem = apiError(response as Any).map(CoachVenueText.error) ?? String(localized: "coachVenues.error.UNKNOWN")
            }
        }
    }

    private func remove(_ off: Components.Schemas.CoachTimeOff) {
        Task {
            guard let client = await session.client() else { return }
            if case let .ok(ok)? = try? await client.removeMyCoachTimeOff(path: .init(id: off.id)),
               let fresh = try? ok.body.json.data {
                items = fresh.items
            }
        }
    }
}
