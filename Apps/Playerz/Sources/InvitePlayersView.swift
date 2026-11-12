import PlayerzAPI
import SwiftUI

/// «Покани играчи» (playerz-ios#14), the web's invite sheet: add people the
/// booker has played with, or share a link that adds whoever opens it and
/// signs in, while the court has room and until the start. Payment stays at
/// the club.
struct InvitePlayersView: View {
    let bookingId: String
    let spotsLeft: Int
    @Bindable var session: SessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var coPlayers: [Components.Schemas.CoPlayer] = []
    @State private var loaded = false
    @State private var adding: String?
    @State private var added: Set<String> = []
    @State private var link: URL?
    @State private var liveLinks: Int
    @State private var linksStopped = false
    @State private var busy = false
    @State private var problem: String?

    init(bookingId: String, spotsLeft: Int, liveLinks: Int, session: SessionModel) {
        self.bookingId = bookingId
        self.spotsLeft = spotsLeft
        self.session = session
        _liveLinks = State(initialValue: liveLinks)
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        BrandDarkSheet(
            title: String(localized: "myBookings.players.sheetTitle"),
            subtitle: String(localized: "myBookings.players.sheetDescription \(spotsLeft)")
        ) {
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.danger)
            }
            sectionTitle(String(localized: "myBookings.players.recent"))
            if loaded, coPlayers.isEmpty {
                Text(String(localized: "myBookings.players.recentEmpty"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            } else if !loaded {
                ProgressView().frame(maxWidth: .infinity)
            }
            ForEach(coPlayers, id: \.userId) { player in
                row(player)
            }
            sectionTitle(String(localized: "myBookings.players.linkTitle"))
            if let link {
                ShareLink(
                    item: link,
                    subject: Text(String(localized: "myBookings.players.shareTitle")),
                    message: Text(String(localized: "myBookings.players.shareTitle"))
                ) {
                    Label(String(localized: "myBookings.players.share"), systemImage: "square.and.arrow.up")
                        .labelStyle(.brandPill)
                }
                .buttonStyle(.brandPrimary)
            } else {
                Button(action: makeLink) {
                    Label(String(localized: "myBookings.players.share"), systemImage: "link")
                        .labelStyle(.brandPill)
                }
                .buttonStyle(.brandPrimary)
                .disabled(busy)
            }
            if let note = linkNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
            }
            if liveLinks > 0 {
                Button(String(localized: "myBookings.players.stopLinks"), role: .destructive, action: stopLinks)
                    .font(Theme.Typography.button)
                    .foregroundStyle(Theme.Palette.danger)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                    .disabled(busy)
            }
            Button(String(localized: "common.done"), action: close)
                .buttonStyle(.brandSecondary)
                .padding(.top, Theme.Spacing.s)
        }
        .task { await loadCoPlayers() }
    }

    /// What the link section says under its button.
    private var linkNote: String? {
        if linksStopped { return String(localized: "myBookings.players.linksStopped") }
        if link != nil { return String(localized: "myBookings.players.linkReady") }
        if liveLinks > 0 { return String(localized: "myBookings.players.liveLinks \(liveLinks)") }
        return nil
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.72))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, Theme.Spacing.s)
    }

    /// Someone the booker has played with, and «Добави», or a tick once added.
    private func row(_ player: Components.Schemas.CoPlayer) -> some View {
        let name = player.name ?? String(localized: "messages.unnamed")
        // At the accessibility sizes «Добави» goes under the name instead of cutting it.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
        return layout {
            HStack(spacing: Theme.Spacing.m) {
                // Decoration: at the accessibility sizes the name needs the width.
                if !typeSize.isAccessibilitySize {
                    BrandAvatar(name: player.name, url: session.mediaURL(player.avatarUrl))
                }
                Text(name)
                    .font(Theme.Typography.rowTitle)
                    .foregroundStyle(.white)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if added.contains(player.userId) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.accentFill)
                    .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                    .accessibilityLabel(String(localized: "myBookings.players.added"))
            } else {
                Button(String(localized: "myBookings.players.add")) { add(player) }
                    .buttonStyle(.brandSecondary(fullWidth: false))
                    .disabled(adding != nil)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.sheetRow, in: .rect(cornerRadius: Theme.Radius.row))
    }

    private func close() {
        dismiss()
    }

    private func loadCoPlayers() async {
        guard let client = await session.client() else { return }
        coPlayers = (try? await client.listBookingCoPlayers(path: .init(id: bookingId)).ok.body.json.data) ?? []
        loaded = true
    }

    private func add(_ player: Components.Schemas.CoPlayer) {
        adding = player.userId
        problem = nil
        Task {
            defer { adding = nil }
            guard let client = await session.client() else { return }
            let response = try? await client.addBookingParticipant(
                path: .init(id: bookingId),
                body: .json(.init(userId: player.userId))
            )
            switch response {
            case .ok, .created: added.insert(player.userId)
            default: problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }

    private func makeLink() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.createBookingInviteLink(path: .init(id: bookingId))
            if case let .created(created) = response, let made = try? created.body.json.data,
                let url = URL(string: made.url)
            {
                link = url
                liveLinks += 1
                linksStopped = false
            } else {
                problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }

    private func stopLinks() {
        busy = true
        problem = nil
        Task {
            defer { busy = false }
            guard let client = await session.client() else { return }
            let response = try? await client.revokeBookingInviteLinks(path: .init(id: bookingId))
            if case .ok = response {
                liveLinks = 0
                link = nil
                linksStopped = true
            } else {
                problem = BookingPlayerText.error(response.flatMap { apiErrorCode($0) })
            }
        }
    }
}
