import MapKit
import SwiftUI

/// The clubs on a map (owner 2026-11-13: "a map with all the clubs in
/// Bulgaria who are bookable in playerz"): a pin per club; a tapped pin shows
/// the club's card under the map, and the card opens its page.
struct ClubsMapView<Card: View>: View {
    let rows: [VenueListModel.Row]
    @ViewBuilder let card: (VenueListModel.Row) -> Card

    @State private var selected: String?
    @State private var position: MapCameraPosition = .region(Self.bulgaria)

    /// The whole country, before any club is read.
    static var bulgaria: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.75, longitude: 25.3),
            span: MKCoordinateSpan(latitudeDelta: 3.6, longitudeDelta: 6.2)
        )
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Map(position: $position, selection: $selected) {
                ForEach(rows) { row in
                    Marker(row.name, systemImage: "sportscourt.fill", coordinate: CLLocationCoordinate2D(latitude: row.lat, longitude: row.lng))
                        .tint(Theme.Palette.accentFill)
                        .tag(row.id)
                }
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .frame(height: 420)
            .clipShape(.rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline))
            .accessibilityLabel(String(localized: "venues.map.label \(rows.count)"))

            if let id = selected, let row = rows.first(where: { $0.id == id }) {
                card(row)
            } else if !rows.isEmpty {
                Text(String(localized: "venues.map.hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        // The pins in view once they arrive; the country while there are none.
        .onChange(of: rows.map(\.id), initial: true) { _, _ in
            selected = selected.flatMap { id in rows.contains { $0.id == id } ? id : nil }
            position = rows.isEmpty ? .region(Self.bulgaria) : .automatic
        }
    }
}
