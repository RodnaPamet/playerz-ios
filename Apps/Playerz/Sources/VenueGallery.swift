import PlayerzAPI
import SwiftUI

/// A venue's gallery (#55): the club's photos after the cover, in the club's
/// order, as a row of tiles; a tap opens them full screen, one at a time.
/// Each is read to VoiceOver by the club's own description (`alt`).
struct VenueGallery: View {
    let photos: [Components.Schemas.VenuePhoto]
    let serverURL: String

    @State private var opened: Int?
    @ScaledMetric(relativeTo: .body) private var tileHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(String(localized: "venue.photos"))
                .font(Theme.Typography.sectionTitle)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Theme.Spacing.l)
            ScrollView(.horizontal) {
                LazyHStack(spacing: Theme.Spacing.m) {
                    ForEach(photos.indices, id: \.self) { i in
                        Button { opened = i } label: {
                            VenueCover(photo: photos[i], seed: "\(i)", serverURL: serverURL)
                                .frame(width: tileHeight * 1.5, height: tileHeight)
                                .clipShape(.rect(cornerRadius: Theme.Radius.tile))
                        }
                        .buttonStyle(.brandCard)
                        .accessibilityLabel(photos[i].alt)
                        .accessibilityAddTraits(.isImage)
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .fullScreenCover(item: Binding(get: { opened.map(Opened.init) }, set: { opened = $0?.index })) { start in
            Viewer(photos: photos, serverURL: serverURL, index: start.index).outsideShellBar()
        }
    }

    private struct Opened: Identifiable {
        let index: Int
        var id: Int { index }
    }

    /// The photos full screen, swiped through, on black; «Готово» closes.
    private struct Viewer: View {
        let photos: [Components.Schemas.VenuePhoto]
        let serverURL: String
        @State var index: Int
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                TabView(selection: $index) {
                    ForEach(photos.indices, id: \.self) { i in
                        AsyncImage(url: VenueCover.url(for: photos[i], pixelWidth: 1600, serverURL: serverURL)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else {
                                ProgressView().tint(.white)
                            }
                        }
                        .accessibilityLabel(photos[i].alt)
                        .accessibilityAddTraits(.isImage)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
                .background(Color.black)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done")) { dismiss() }
                    }
                }
                .toolbarBackground(.black, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
    }
}
