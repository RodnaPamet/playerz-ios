import PlayerzAPI
import SwiftUI

/// «Предложете час за мача» (#23), a league match's time, as the web's sheet:
/// a day, a court at the tournament's venue, then a free time two hours ahead
/// at the earliest. The court is held in the proposer's name at its own price,
/// paid at the club, until the other side accepts; it lapses after a day.
struct ProposeMatchSheet: View {
    let venueId: String
    let timezone: String
    let opponents: String
    @Bindable var session: SessionModel
    let propose: (_ resourceId: String, _ startTs: Date, _ minutes: Int) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var day: String
    @State private var court: String?
    @State private var availability: Components.Schemas.VenueAvailability?
    @State private var sending = false

    /// Two hours from now at the earliest, as the server takes them.
    private static let lead: TimeInterval = 2 * 3600

    init(
        venueId: String,
        timezone: String,
        opponents: String,
        session: SessionModel,
        propose: @escaping (_ resourceId: String, _ startTs: Date, _ minutes: Int) async -> Bool
    ) {
        self.venueId = venueId
        self.timezone = timezone
        self.opponents = opponents
        self.session = session
        self.propose = propose
        _day = State(initialValue: LessonDays.days(from: .now, timezone: timezone).first ?? "")
    }

    private var resource: Components.Schemas.ResourceSlots? {
        availability?.resources.first { $0.resourceId == court } ?? availability?.resources.first
    }

    private var times: [Components.Schemas.AvailabilitySlot] {
        let earliest = Date.now.addingTimeInterval(Self.lead)
        return resource?.slots.filter { $0.available && $0.startTs >= earliest } ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "tournaments.propose.description \(opponents)")).foregroundStyle(.secondary)
                }
                Section {
                    Picker(String(localized: "tournaments.propose.day"), selection: $day) {
                        ForEach(LessonDays.days(from: .now, timezone: timezone), id: \.self) { day in
                            Text(LessonDayText.label(day)).tag(day)
                        }
                    }
                    if let availability, availability.resources.count > 1 {
                        Picker(String(localized: "tournaments.propose.court"), selection: $court) {
                            ForEach(availability.resources, id: \.resourceId) { resource in
                                Text(resource.name).tag(Optional(resource.resourceId))
                            }
                        }
                    }
                }
                Section {
                    if availability != nil, times.isEmpty {
                        Text(String(localized: "tournaments.propose.none")).foregroundStyle(.secondary)
                    }
                    ForEach(times, id: \.startTs) { slot in
                        Button { send(slot) } label: {
                            LabeledContent(
                                LessonDayText.time(slot.startTs, timezone: timezone),
                                value: CoachText.money(slot.priceCents, resource?.currency ?? "EUR")
                            )
                        }
                        .tint(.primary)
                        .disabled(sending)
                    }
                } header: {
                    Text(String(localized: "tournaments.propose.times \(resource?.name ?? "")"))
                } footer: {
                    Text(String(localized: "tournaments.propose.hint"))
                }
            }
            .navigationTitle(String(localized: "tournaments.propose.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "tournaments.propose.cancel"), action: close)
                }
            }
            .task(id: day) { await load() }
        }
    }

    private func close() {
        dismiss()
    }

    private func load() async {
        guard let client = await session.client() else { return }
        let query = Operations.getVenueAvailability.Input.Query(date: day)
        if let fresh = try? await client.getVenueAvailability(path: .init(id: venueId), query: query).ok.body.json.data {
            availability = fresh
            if court == nil || !fresh.resources.contains(where: { $0.resourceId == court }) {
                court = fresh.resources.first?.resourceId
            }
        }
    }

    private func send(_ slot: Components.Schemas.AvailabilitySlot) {
        guard let resource else { return }
        let minutes = slot.durations?.first?.minutes ?? Int(slot.endTs.timeIntervalSince(slot.startTs) / 60)
        sending = true
        Task {
            defer { sending = false }
            if await propose(resource.resourceId, slot.startTs, minutes) { dismiss() }
        }
    }
}
