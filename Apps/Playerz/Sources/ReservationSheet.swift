import PlayerzAPI
import SwiftUI

/// The hours picked at a venue, reviewed, reserved together, then paid
/// (owner 2026-11-13: «show a summary screen which prompts to reserve and
/// takes to payment»). Payment is at the club, as every pilot club takes it;
/// a booking a club wants paid online (PENDING) is said so, until the card
/// step exists (Stripe keys: later).
struct ReservationSheet: View {
    let model: VenueDetailModel
    let session: SessionModel
    let venueId: String
    let venueName: String

    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .review
    @AccessibilityFocusState private var headingFocused: Bool

    enum Stage { case review, sending, paid([VenueDetailModel.Outcome]) }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .review: review
                case .sending:
                    ProgressView(String(localized: "reserve.sending"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .paid(outcomes): payment(outcomes)
                }
            }
            .brandPage()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
        }
        // DEBUG only (`PLAYERZ_RESERVE=1`), on the local server: the payment step.
        .task { if DebugLaunch.reserve { await reserve() } }
        .onAppear { model.summaryOpen = true }
        .onDisappear { model.summaryOpen = false }
    }

    private var title: String {
        switch stage {
        case .review, .sending: String(localized: "reserve.title")
        case .paid: String(localized: "reserve.payment.title")
        }
    }

    // MARK: - Review

    private var review: some View {
        let blocks = model.blocks
        let currency = model.picks.first?.currency ?? "EUR"
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text(venueName)
                    .font(Theme.Typography.display(30, relativeTo: .title2))
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                BrandContentCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                            if index > 0 { Divider() }
                            blockRow(block, currency: currency)
                        }
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "reserve.total")).font(.headline)
                    Spacer()
                    Text(Self.money(blocks.reduce(0) { $0 + $1.priceCents }, currency))
                        .font(Theme.Typography.display(34, relativeTo: .title))
                }
                .accessibilityElement(children: .combine)
                Label(String(localized: "reserve.payAtClub"), systemImage: "building.columns")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if blocks.count > 1 {
                    Text(String(localized: "reserve.several \(blocks.count)"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await reserve() }
                } label: {
                    Text(String(localized: "reserve.button"))
                }
                .buttonStyle(.brandPrimary)
                .disabled(blocks.isEmpty)
            }
            .padding(Theme.Spacing.l)
        }
    }

    private func blockRow(_ block: HourlySlots.Block, currency: String) -> some View {
        let pick = model.pick(for: block)
        return HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.place(pick?.placeName ?? "", sport: pick?.sport ?? ""))
                    .font(Theme.Typography.rowTitle)
                Text(Self.when(block, timezone: model.timezone))
                    .font(Theme.Typography.displayUpright(20, relativeTo: .body))
                    .monospacedDigit()
                Text(String(localized: "reserve.hours \(block.hours)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Self.money(block.priceCents, currency)).font(.headline)
            Button {
                for pick in model.picks where pick.resourceId == block.resourceId && pick.start >= block.start && pick.start < block.end {
                    if let court = model.courts.first(where: { $0.resourceId == pick.resourceId }),
                       let slot = court.bookable.first(where: { $0.startTs == pick.start }) {
                        model.toggle(court, slot)
                    }
                }
                if model.picks.isEmpty { dismiss() }
            } label: {
                Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "reserve.remove"))
        }
        .accessibilityElement(children: .combine)
    }

    private func reserve() async {
        stage = .sending
        let outcomes = await model.reserve(session, venueId: venueId)
        stage = .paid(outcomes)
    }

    // MARK: - Payment

    private func payment(_ outcomes: [VenueDetailModel.Outcome]) -> some View {
        let made = outcomes.compactMap(\.booking)
        let atClub = made.filter { $0.status == "CONFIRMED" }
        let online = made.filter { $0.status == "PENDING" }
        let failed = outcomes.filter { $0.booking == nil }
        let currency = made.first?.currency ?? "EUR"
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !atClub.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(String(localized: "reserve.payment.atClub"))
                            .font(.headline)
                        Text(Self.money(atClub.reduce(0) { $0 + $1.totalCents }, currency))
                            .font(Theme.Typography.display(56, relativeTo: .largeTitle))
                        Text(String(localized: "reserve.payment.atClubHint"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($headingFocused)
                }
                if !online.isEmpty {
                    Label(String(localized: "reserve.payment.onlineSoon"), systemImage: "creditcard")
                        .font(.subheadline)
                }
                BrandContentCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        ForEach(outcomes) { outcome in
                            outcomeRow(outcome)
                        }
                    }
                }
                if !failed.isEmpty, !model.picks.isEmpty {
                    Button(String(localized: "reserve.retry")) { Task { await reserve() } }
                        .buttonStyle(.brandSecondary)
                }
                if !made.isEmpty {
                    Button(String(localized: "reserve.toBookings")) {
                        session.requestedTab = .bookings
                        dismiss()
                    }
                    .buttonStyle(.brandPrimary)
                }
                Button(String(localized: "reserve.done")) { dismiss() }
                    .buttonStyle(.brandSecondary)
            }
            .padding(Theme.Spacing.l)
        }
        .onAppear { headingFocused = true }
    }

    private func outcomeRow(_ outcome: VenueDetailModel.Outcome) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: outcome.booking == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(outcome.booking == nil ? Theme.Palette.danger : Theme.Palette.success)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.place(outcome.placeName, sport: outcome.sport)).font(Theme.Typography.rowTitle)
                Text(Self.when(outcome.block, timezone: model.timezone)).monospacedDigit()
                Text(outcome.booking == nil
                    ? (outcome.problem ?? String(localized: "venue.bookFailed"))
                    : String(localized: "reserve.booked"))
                    .font(.footnote)
                    .foregroundStyle(outcome.booking == nil ? Theme.Palette.danger : .secondary)
            }
            Spacer()
            if let booking = outcome.booking {
                Text(Self.money(booking.totalCents, booking.currency)).font(.headline)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Text

    /// «Корт 1»; a name that already says what it is stays as it is.
    nonisolated static func place(_ name: String, sport: String) -> String {
        let word = PlaceText.label(sport: sport)
        return name.localizedCaseInsensitiveContains(word) ? name : "\(word) · \(name)"
    }

    /// «сб, 14.11 · 18:00 – 20:00», on the venue's clock.
    nonisolated static func when(_ block: HourlySlots.Block, timezone: String) -> String {
        let zone = TimeZone(identifier: timezone) ?? .current
        let day = block.start.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).day().month(.twoDigits))
        let clock = Date.FormatStyle(timeZone: zone).hour(.twoDigits(amPM: .omitted)).minute()
        return "\(day) · \(block.start.formatted(clock)) – \(block.end.formatted(clock))"
    }

    nonisolated static func money(_ cents: Int, _ currency: String) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: currency))
    }
}

/// The hours picked so far, above the tab bar: how many, the total, onward.
struct PicksBar: View {
    let count: Int
    let totalCents: Int
    let currency: String
    let next: () -> Void
    let clear: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button(action: clear) {
                Image(systemName: "xmark").font(.headline)
                    .frame(width: Theme.minTarget, height: Theme.minTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Palette.onInverse)
            .accessibilityLabel(String(localized: "reserve.clear"))
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "reserve.bar.hours \(count)"))
                    .font(.footnote.weight(.semibold))
                Text(ReservationSheet.money(totalCents, currency))
                    .font(Theme.Typography.display(24, relativeTo: .title3))
            }
            .foregroundStyle(Theme.Palette.onInverse)
            .accessibilityElement(children: .combine)
            Spacer()
            Button(action: next) {
                Text(String(localized: "reserve.bar.next"))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, Theme.Spacing.s)
            }
            .buttonStyle(.brandPrimary(fullWidth: false))
        }
        .padding(.leading, Theme.Spacing.xs)
        .padding(.trailing, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Palette.inverse, in: .capsule)
        .themeShadow(.floating)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.s)
    }
}
