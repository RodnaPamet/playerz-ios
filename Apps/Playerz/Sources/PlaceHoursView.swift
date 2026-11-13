import PlayerzAPI
import SwiftUI

/// One place's free hours, on their own screen (owner 2026-11-13: a place
/// tapped «has to take me to the slot picking screen which in turn takes me
/// to the summary and reservation screen»). The days as on the club's page,
/// the hours to pick, and the bar to the summary. The picks are the venue's,
/// so hours picked on another place stay picked.
struct PlaceHoursView: View {
    let model: VenueDetailModel
    let session: SessionModel
    let venueId: String
    let resourceId: String

    @State private var reviewing = DebugLaunch.review

    private var court: VenueDetailModel.Court? {
        model.courts.first { $0.resourceId == resourceId }
    }

    var body: some View {
        List {
            if let court {
                Section {
                    if court.bookable.isEmpty {
                        Text(String(localized: "venue.noSlots")).foregroundStyle(.secondary)
                    } else {
                        ForEach(court.bookable, id: \.startTs) { slot in
                            SlotRow(
                                slot: slot,
                                currency: court.currency,
                                timezone: model.timezone,
                                picked: model.isPicked(court, slot)
                            ) {
                                model.toggle(court, slot)
                            }
                        }
                    }
                } header: {
                    HStack(spacing: Theme.Spacing.s) {
                        SportPitchView(sport: court.sport)
                            .frame(width: 56, height: 36)
                        Text(PlaceText.roof(PlaceWord.of(court.sport), indoor: court.isIndoor))
                        if let forecast = model.forecast(for: court) {
                            Spacer()
                            Text(forecast)
                        }
                    }
                }
                .brandListRow()
            } else if model.phase == .loading {
                ProgressView(String(localized: "common.loading"))
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.picks.isEmpty {
                PicksBar(
                    count: model.picks.count,
                    totalCents: model.picksTotalCents,
                    currency: model.picks.first?.currency ?? "EUR",
                    next: { reviewing = true },
                    clear: { model.clearPicks() }
                )
            }
        }
        .sheet(isPresented: $reviewing) {
            ReservationSheet(model: model, session: session, venueId: venueId, venueName: model.venue?.name ?? "")
                .outsideShellBar()
        }
        .brandPage()
        .navigationTitle(court?.name ?? "")
        .brandChipBar {
            if model.days.count > 1 {
                BrandChipRow {
                    ForEach(model.days) { day in
                        BrandChip(
                            GameText.filterDay(day, zone: model.timezone),
                            isSelected: day.apiDate == model.selectedDate
                        ) {
                            Task { await model.select(session, venueId: venueId, day: day) }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "venue.dayPicker"))
            }
        }
        .brandHeader(.back(court.map { ReservationSheet.place($0.name, sport: $0.sport) } ?? ""))
    }
}
