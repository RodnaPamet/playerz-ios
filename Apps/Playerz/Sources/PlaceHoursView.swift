import PlayerzAPI
import SwiftUI

/// One place's free hours, on their own screen (owner 2026-11-13: a place
/// tapped «has to take me to the slot picking screen which in turn takes me
/// to the summary and reservation screen»). The days as on the club's page,
/// the hours to pick, and the bar to the summary. The picks are the venue's,
/// so hours picked on another place stay picked.
///
/// A swipe left or right moves to the next or the previous place of the
/// club's grid, in its order (owner 2026-11-13: "swipable right and left to
/// the next sport within this list").
struct PlaceHoursView: View {
    let model: VenueDetailModel
    let session: SessionModel
    let venueId: String
    /// The places the swipe moves through: the club's grid, in its order.
    let resourceIds: [String]

    @State private var current: String
    @State private var reviewing = DebugLaunch.review

    init(model: VenueDetailModel, session: SessionModel, venueId: String, resourceIds: [String], start: String) {
        self.model = model
        self.session = session
        self.venueId = venueId
        self.resourceIds = resourceIds.contains(start) ? resourceIds : [start]
        _current = State(initialValue: start)
    }

    private var court: VenueDetailModel.Court? {
        model.courts.first { $0.resourceId == current }
    }

    var body: some View {
        TabView(selection: $current) {
            ForEach(resourceIds, id: \.self) { id in
                page(id).tag(id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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


    /// One place's page: its sport's banner and its hours.
    private func page(_ id: String) -> some View {
        let place = model.courts.first { $0.resourceId == id }
        return List {
            if let banner = model.banner {
                Section {
                    Text(banner)
                        .foregroundStyle(model.bannerIsError ? Theme.Palette.danger : Theme.Palette.success)
                }
                .brandListRow()
            }
            if let court = place {
                Section {
                    if court.bookable.isEmpty {
                        Text(String(localized: "venue.noSlots")).foregroundStyle(.secondary)
                    }
                    // The hours as a grid by part of the day (the design draft).
                    if !court.hours.isEmpty {
                        HourGrid(
                            court: court, timezone: model.timezone,
                            isPicked: { model.isPicked(court, $0) },
                            toggle: { model.toggle(court, $0) }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    // The place's sport in its photo (owner 2026-11-13: "use
                    // the pictures to highlight each selected sport page").
                    SportBanner(
                        sport: court.sport,
                        title: court.name,
                        subtitle: PlaceText.roof(PlaceWord.of(court.sport), indoor: court.isIndoor)
                    ) {
                        if let forecast = model.forecast(for: court) { Text(forecast) }
                    }
                    .textCase(nil)
                    .padding(.horizontal, -Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.s)
                }
                .brandListRow()
            } else if model.phase == .loading {
                ProgressView(String(localized: "common.loading"))
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
    }
}
