import PlayerzAPI
import SwiftUI

struct VenueDetailView: View {
    let venueId: String
    @Bindable var session: SessionModel
    @State private var model = VenueDetailModel()
    @State private var offerPush = false

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView(String(localized: "common.loading"))
            case .failed:
                ContentUnavailableView {
                    Text(String(localized: "venue.failed"))
                } actions: {
                    Button(String(localized: "venues.retry")) {
                        Task { await model.load(session, venueId: venueId) }
                    }
                }
            case .loaded:
                content
            }
        }
        .navigationTitle(model.venue?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let slug = model.venue?.slug {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(String(localized: "bookings.title")) {
                        BookingsView(slug: slug, session: session)
                    }
                }
            }
        }
        .task { await model.load(session, venueId: venueId) }
        .onChange(of: model.banner) { _, banner in
            // A banner appearing mid-list is invisible to VoiceOver: focus does
            // not move, and the user is told nothing about the booking they
            // just made.
            guard let banner else { return }
            AccessibilityNotification.Announcement(banner).post()
        }
        .onChange(of: model.lastBookingSucceeded) { _, booked in
            // Only after a booking, and only once: iOS grants exactly one
            // system prompt, so it is spent at the moment the offer is
            // concrete rather than on a cold launch.
            guard booked else { return }
            Task {
                if await !PushRegistrar.shared.alreadyDecided() { offerPush = true }
            }
        }
        .alert(String(localized: "push.askTitle"), isPresented: $offerPush) {
            Button(String(localized: "push.allow")) {
                Task { await PushRegistrar.shared.requestAndRegister(session) }
            }
            // "Not now" is recoverable; a system "Don't Allow" is not. Asking
            // ourselves first is what preserves the one real prompt.
            Button(String(localized: "push.notNow"), role: .cancel) {}
        } message: {
            Text(String(localized: "push.askBody"))
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            if model.days.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.days) { day in
                                Button {
                                    Task {
                                        await model.select(session, venueId: venueId, day: day)
                                    }
                                } label: {
                                    Text(day.label(timeZone: model.timezone, today: String(localized: "venue.today")))
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        // 44pt is Apple's minimum tappable
                                        // height. The capsule was ~28pt tall,
                                        // which is a hard target for anyone
                                        // with a tremor and fails the guideline
                                        // outright.
                                        .frame(minWidth: 44, minHeight: 44)
                                        .background(
                                            day.apiDate == model.selectedDate
                                                ? Color.accentColor.opacity(0.18)
                                                : Color.clear,
                                            in: Capsule()
                                        )
                                        // The padded frame, not just the glyph,
                                        // takes the tap.
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(
                                    day.apiDate == model.selectedDate ? [.isSelected] : []
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let banner = model.banner {
                Section {
                    Text(banner)
                        // Colour alone must not carry the meaning — the words
                        // already say which outcome it is.
                        .foregroundStyle(model.bannerIsError ? .red : .green)
                }
            }

            if model.showsAnyForecast {
                Section { WeatherAttribution() }
            }

            ForEach(model.courts, id: \.resourceId) { court in
                Section {
                    if court.bookable.isEmpty {
                        Text(String(localized: "venue.noSlots"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(court.bookable, id: \.startTs) { slot in
                            SlotRow(
                                slot: slot,
                                currency: court.currency,
                                busy: model.bookingSlot == slot.startTs,
                                disabled: model.bookingSlot != nil
                            ) {
                                Task {
                                    await model.book(
                                        session,
                                        venueId: venueId,
                                        resourceId: court.resourceId,
                                        slot: slot
                                    )
                                }
                            }
                        }
                    }
                } header: {
                    CourtHeader(court: court, forecast: model.forecast(for: court))
                }
            }
        }
    }
}

/// Apple REQUIRES this wherever WeatherKit data appears.
///
/// Not a courtesy — it is in the terms, and it is an App Review item. The mark
/// and a link to Apple's legal attribution page must both be present, so this
/// renders only when a forecast is actually on screen: attribution for data
/// nobody is being shown would be noise.
private struct WeatherAttribution: View {
    private static let legal = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    var body: some View {
        HStack(spacing: 6) {
            Text(String(localized: "weather.attribution"))
            Link(String(localized: "weather.legal"), destination: Self.legal)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

private struct CourtHeader: View {
    let court: VenueDetailModel.Court
    let forecast: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(court.name)
            Text(
                court.isIndoor
                    ? String(localized: "venue.indoor")
                    : String(localized: "venue.outdoor")
            )
            .foregroundStyle(.secondary)

            // Outdoor courts only — an indoor court's weather is not a fact
            // anybody books on. #211.
            if let forecast {
                Spacer()
                Text(forecast).foregroundStyle(.secondary)
            }
        }
    }
}

private struct SlotRow: View {
    let slot: Components.Schemas.AvailabilitySlot
    let currency: String
    let busy: Bool
    let disabled: Bool
    let book: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the time, the price and the button cannot
        // share a line without truncating one of them.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())

        layout {
            Text(time)
            if !typeSize.isAccessibilitySize { Spacer() }
            Text(price).foregroundStyle(.secondary)

            Button(action: book) {
                if busy {
                    ProgressView()
                } else {
                    Text(String(localized: "venue.book"))
                }
            }
            .buttonStyle(.borderless)
            .disabled(disabled)
            // ═══ WITHOUT THIS, EVERY SLOT IS "Резервирай" ═══
            //
            // A court with twelve free hours renders twelve buttons with the
            // same label. VoiceOver reads the time as a SEPARATE element, so
            // nothing ties the two together and choosing an hour means
            // counting swipes.
            //
            // A ProgressView also has no label, so the busy state announced an
            // unlabelled button — the worst moment to lose the name.
            .accessibilityLabel(
                busy
                    ? String(localized: "venue.booking")
                    : String(format: String(localized: "a11y.bookSlot"), time, price)
            )
        }
    }

    private var time: String {
        slot.startTs.formatted(date: .omitted, time: .shortened)
    }

    private var price: String {
        (Decimal(slot.priceCents) / 100).formatted(.currency(code: currency))
    }
}
