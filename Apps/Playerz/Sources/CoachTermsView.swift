import PlayerzAPI
import SwiftUI

/// «{venue}: цена и часове» (#21): what the coach takes at this venue and when
/// they work there. The court's price is added to the rate. Without hours no
/// lesson can be booked. Terms and hours are saved separately, as on the web.
struct CoachTermsView: View {
    let link: Components.Schemas.MyCoachLink
    let model: CoachLinksModel
    @Bindable var session: SessionModel

    @State private var hourly: String
    @State private var group: String
    @State private var lengths: Set<Int>
    @State private var cutoff: Int
    @State private var week: [Int: [ClockStretch]]
    @State private var problem: String?
    @State private var saved: String?

    /// Monday first, on the venue's week (0 = Sunday … 6 = Saturday).
    private static let days = [1, 2, 3, 4, 5, 6, 0]

    init(link: Components.Schemas.MyCoachLink, model: CoachLinksModel, session: SessionModel) {
        self.link = link
        self.model = model
        self.session = session
        _hourly = State(initialValue: link.hourlyRateCents.map(Self.major) ?? "")
        _group = State(initialValue: link.groupRateCents.map(Self.major) ?? "")
        _lengths = State(initialValue: Set(link.lessonMinutes))
        _cutoff = State(initialValue: link.cancelCutoffHours)
        var week: [Int: [ClockStretch]] = [:]
        for hours in link.hours {
            guard let open = TeachingHours.minutes(hours.open), let close = TeachingHours.minutes(hours.close) else { continue }
            week[hours.dayOfWeek, default: []].append(ClockStretch(open: open, close: close))
        }
        _week = State(initialValue: week)
    }

    var body: some View {
        Form {
            Section {
                Text(String(localized: "coachVenues.terms.description")).foregroundStyle(.secondary)
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            if let saved {
                Section { Text(saved).foregroundStyle(.green) }
            }
            Section {
                // Labelled rows: a placeholder alone is gone once a price is typed.
                LabeledContent(String(localized: "coachVenues.terms.hourly \(link.currency)")) {
                    TextField(text: $hourly, prompt: Text(verbatim: "0")) {
                        Text(String(localized: "coachVenues.terms.hourly \(link.currency)"))
                    }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "coachVenues.terms.group \(link.currency)")) {
                    TextField(text: $group, prompt: Text(verbatim: "—")) {
                        Text(String(localized: "coachVenues.terms.group \(link.currency)"))
                    }
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text(String(localized: "coachVenues.terms.groupHint"))
            }
            Section {
                ForEach(link.lengthOptions, id: \.self) { minutes in
                    Toggle(String(localized: "coachVenues.terms.minutes \(minutes)"), isOn: length(minutes))
                }
            } header: {
                Text(String(localized: "coachVenues.terms.lengths"))
            } footer: {
                Text(String(localized: "coachVenues.terms.lengthsHint"))
            }
            Section {
                Stepper(value: $cutoff, in: 0...168) {
                    LabeledContent(String(localized: "coachVenues.terms.cutoff"), value: cutoff.formatted())
                }
            } footer: {
                Text(String(localized: "coachVenues.terms.cutoffHint"))
            }
            Section {
                Button(String(localized: "coachVenues.terms.save"), action: saveTerms)
                    .disabled(model.busy)
            }
            Section {
                ForEach(Self.days, id: \.self) { day in
                    CoachDayHours(day: day, stretches: stretches(day))
                }
            } header: {
                Text(String(localized: "coachVenues.terms.hours"))
            } footer: {
                Text(String(localized: "coachVenues.terms.hoursHint"))
            }
            Section {
                Button(String(localized: "coachVenues.terms.saveHours"), action: saveHours)
                    .disabled(model.busy)
            }
        }
        .navigationTitle(String(localized: "coachVenues.terms.title \(link.venue.name)"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func major(_ cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Cents for what was typed, in the reader's own decimal style; nil if it is not a price.
    private static func cents(_ typed: String) -> Int? {
        guard let value = try? Decimal(typed.trimmingCharacters(in: .whitespaces), format: .number) else { return nil }
        let cents = NSDecimalNumber(decimal: value * 100).intValue
        return (0...100_000).contains(cents) ? cents : nil
    }

    private func length(_ minutes: Int) -> Binding<Bool> {
        Binding(
            get: { lengths.contains(minutes) },
            set: { on in if on { lengths.insert(minutes) } else { lengths.remove(minutes) } }
        )
    }

    private func stretches(_ day: Int) -> Binding<[ClockStretch]> {
        Binding(get: { week[day] ?? [] }, set: { week[day] = $0 })
    }

    private func saveTerms() {
        problem = nil
        saved = nil
        guard let rate = Self.cents(hourly) else {
            problem = String(localized: "coachVenues.error.hourlyRateCents")
            return
        }
        let groupRate: Int?
        if group.trimmingCharacters(in: .whitespaces).isEmpty {
            groupRate = nil
        } else if let parsed = Self.cents(group) {
            groupRate = parsed
        } else {
            problem = String(localized: "coachVenues.error.groupRateCents")
            return
        }
        guard !lengths.isEmpty else {
            problem = String(localized: "coachVenues.error.lessonMinutes")
            return
        }
        let terms = Components.Schemas.SaveTeachingTermsRequest(
            hourlyRateCents: rate,
            groupRateCents: groupRate,
            lessonMinutes: lengths.sorted(),
            cancelCutoffHours: cutoff
        )
        Task {
            if await model.saveTerms(link, terms, session) {
                saved = String(localized: "coachProfile.saved")
            } else {
                problem = model.line?.text
            }
        }
    }

    private func saveHours() {
        problem = nil
        saved = nil
        guard week.values.allSatisfy({ TeachingHours.valid($0.map { ($0.open, $0.close) }) }) else {
            problem = String(localized: "coachVenues.error.hours")
            return
        }
        let hours = week.keys.sorted().flatMap { day in
            (week[day] ?? []).sorted { $0.open < $1.open }.map {
                Components.Schemas.CoachTeachingHours(
                    dayOfWeek: day, open: TeachingHours.clock($0.open), close: TeachingHours.clock($0.close)
                )
            }
        }
        Task {
            if await model.saveHours(link, hours, session) {
                saved = String(localized: "coachProfile.saved")
            } else {
                problem = model.line?.text
            }
        }
    }
}
