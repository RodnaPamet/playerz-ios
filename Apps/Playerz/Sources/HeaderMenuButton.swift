import SwiftUI

/// A round button on the header band that opens a menu («Още»): the face of
/// `BrandHeaderButton`, for a Menu, whose label cannot be a Button.
///
/// Outside Brand/ for now; it belongs beside `BrandHeaderButton` once the
/// restyle's shared files are open again.
struct HeaderMenuButton<Content: View>: View {
    let systemImage: String
    let label: String
    let content: Content

    init(systemImage: String = "ellipsis", label: String, @ViewBuilder content: () -> Content) {
        self.systemImage = systemImage
        self.label = label
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.onHeader)
                .padding(Theme.Spacing.s)
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                .background(.white.opacity(0.14), in: .circle)
                .contentShape(.circle)
        }
        .accessibilityLabel(label)
        // As the band's other buttons: a larger text size shows the name instead.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: systemImage) }
    }
}

#Preview {
    HStack {
        HeaderMenuButton(label: "Още") {
            Button(String("Блокирай")) {}
            Button(String("Сигнал"), role: .destructive) {}
        }
        BrandHeaderButton(systemImage: "bell", label: "Известия") {}
    }
    .padding()
    .background(BrandHeaderBackdrop())
}
