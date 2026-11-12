import SwiftUI

/// The heart on a club (projectZ#672, owner 2026-11-12): on and off at once,
/// saved behind it. A round button that sits on a cover or in the header band.
struct FavouriteHeart: View {
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: isOn ? "heart.fill" : "heart")
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? Theme.Palette.badge : Theme.Palette.onHeader)
                .frame(width: Theme.minTarget, height: Theme.minTarget)
                .background(Theme.Palette.headerInk.opacity(0.55), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: isOn ? "favourites.remove" : "favourites.add"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

#Preview {
    HStack {
        FavouriteHeart(isOn: false) {}
        FavouriteHeart(isOn: true) {}
    }
    .padding()
    .background(Theme.Palette.page)
}
