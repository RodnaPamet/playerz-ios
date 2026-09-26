import PlayerzAPI
import SwiftUI

struct VenueDetailView: View {
    let venueId: String
    @Bindable var session: SessionModel
    @State private var model = VenueDetailModel()

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
        .task { await model.load(session, venueId: venueId) }
    }

    @ViewBuilder
    private var content: some View {
        List {
            if let banner = model.banner {
                Section { Text(banner).foregroundStyle(model.bannerIsError ? .red : .green) }
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

    var body: some View {
        HStack {
            Text(slot.startTs.formatted(date: .omitted, time: .shortened))
            Spacer()
            Text(price)
                .foregroundStyle(.secondary)
            Button(action: book) {
                if busy {
                    ProgressView()
                } else {
                    Text(String(localized: "venue.book"))
                }
            }
            .buttonStyle(.borderless)
            .disabled(disabled)
        }
    }

    private var price: String {
        (Decimal(slot.priceCents) / 100).formatted(.currency(code: currency))
    }
}
