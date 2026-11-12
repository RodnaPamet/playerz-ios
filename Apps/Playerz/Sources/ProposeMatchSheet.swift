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
        BrandDarkSheet(
            title: String(localized: "tournaments.propose.title"),
            subtitle: String(localized: "tournaments.propose.description \(opponents)")
        ) {
            section(String(localized: "tournaments.propose.day")) {
                BrandChipRow {
                    ForEach(LessonDays.days(from: .now, timezone: timezone), id: \.self) { item in
                        BrandChip(LessonDayText.label(item), isSelected: day == item) { day = item }
                    }
                }
                // To the sheet's edges, so a long row visibly runs on.
                .padding(.horizontal, -Theme.Spacing.l)
            }
            if let availability, availability.resources.count > 1 {
                section(String(localized: "tournaments.propose.court")) {
                    BrandChipRow {
                        ForEach(availability.resources, id: \.resourceId) { item in
                            BrandChip(item.name, isSelected: court == item.resourceId) { court = item.resourceId }
                        }
                    }
                    .padding(.horizontal, -Theme.Spacing.l)
                }
            }
            section(String(localized: "tournaments.propose.times \(resource?.name ?? "")")) {
                if availability == nil {
                    ProgressView().frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                } else if times.isEmpty {
                    note(String(localized: "tournaments.propose.none"))
                }
                ForEach(times, id: \.startTs) { slot in
                    BrandSheetRow(
                        title: LessonDayText.time(slot.startTs, timezone: timezone),
                        subtitle: CoachText.money(slot.priceCents, resource?.currency ?? "EUR"),
                        systemImage: "clock"
                    ) { send(slot) }
                    .disabled(sending)
                }
            }
            note(String(localized: "tournaments.propose.hint"))
            Button(String(localized: "tournaments.propose.cancel"), action: close)
                .buttonStyle(.brandSecondary)
                .padding(.top, Theme.Spacing.s)
        }
        .task(id: day) { await load() }
    }

    /// A titled part of the sheet, as the filters' sheets have them.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.72))
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
