import PlayerzAPI
import SwiftUI

/// A coach's page (playerz-ios#19), the web's `/coaches/{slug}`: who they are,
/// what they teach and to which levels, where and for how much, and their
/// reviews; «Запишете урок» books one.
struct CoachView: View {
    let slug: String
    @Bindable var session: SessionModel

    @State private var coach: Components.Schemas.PublicCoach?
    @State private var failed = false
    @State private var reviews: CoachReviewsModel
    /// «Запишете урок»; a DEBUG launch can open it at once (DebugLaunch).
    @State private var booking = false
    /// The name is on the top card; the header carries it only once the card is scrolled away (#55).
    @State private var heroShown = true

    init(slug: String, session: SessionModel) {
        self.slug = slug
        self.session = session
        _reviews = State(initialValue: CoachReviewsModel(slug: slug))
    }

    private var name: String { coach.map { CoachText.name($0.name) } ?? "" }

    var body: some View {
        Group {
            if let coach {
                List {
                    Section {
                        CoachHero(coach: coach, serverURL: session.serverURL)
                            .onAppear { heroShown = true }
                            .onDisappear { heroShown = false }
                    }
                    // The card is its own surface: no row box around it.
                    .bareListRow()
                    if !coach.venues.isEmpty {
                        Section {
                            Button(String(localized: "coaches.lesson.title")) { booking = true }
                                .buttonStyle(.brandPrimary)
                        }
                        .bareListRow()
                    }
                    Group {
                        sections(coach)
                    }
                    .brandListRow()
                }
                .refreshable { await load() }
                .confirmationDialog(
                    String(localized: "coaches.reviews.deleteTitle"),
                    isPresented: $reviews.confirmingDelete,
                    titleVisibility: .visible,
                    presenting: reviews.deleting
                ) { review in
                    Button(String(localized: "coaches.reviews.deleteYes"), role: .destructive) {
                        Task { await reviews.delete(review, session) }
                    }
                    Button(String(localized: "coaches.reviews.keep"), role: .cancel) {}
                } message: { _ in
                    Text(String(localized: "coaches.reviews.deleteDescription"))
                }
                .brandSheet(item: $reviews.reporting, detents: [.medium, .large]) { reported in
                    ReportSheet(title: String(localized: "messages.reportReview")) { reason, details in
                        await reviews.send(report: reported.id, reason: reason, details: details, session)
                    } done: {
                        reviews.reporting = nil
                    }
                }
            } else if failed {
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "coaches.page.failed")) {
                    Button(String(localized: "venues.retry"), action: retry)
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView(String(localized: "common.loading"))
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(name)
        .brandHeader(.back(heroShown && coach != nil ? "" : name))
        .task {
            await load()
            if DebugLaunch.coachBook != nil, coach?.venues.isEmpty == false { booking = true }
        }
        .navigationDestination(isPresented: $booking) {
            if let coach {
                LessonBookingView(coach: coach, session: session)
            }
        }
    }

    @ViewBuilder private func sections(_ coach: Components.Schemas.PublicCoach) -> some View {
        if let bio = coach.bio, !bio.isEmpty {
            Section(String(localized: "coaches.page.about")) { Text(bio) }
        }
        if let qualifications = coach.qualifications, !qualifications.isEmpty {
            Section(String(localized: "coaches.page.qualifications")) { Text(qualifications) }
        }
        Section {
            if coach.venues.isEmpty {
                Text(String(localized: "coaches.page.nowhere")).foregroundStyle(.secondary)
            }
            ForEach(coach.venues, id: \.linkId) { venue in
                CoachVenueRow(venue: venue)
            }
        } header: {
            Text(String(localized: "coaches.page.venues"))
        } footer: {
            Text(String(localized: "coaches.page.courtNote"))
        }
        CoachReviewsSection(model: reviews, session: session)
    }

    private func retry() {
        failed = false
        Task { await load() }
    }

    private func load() async {
        await reviews.load(session)
        guard let client = await session.client() else {
            failed = true
            return
        }
        do {
            coach = try await client.getCoach(path: .init(slug: slug)).ok.body.json.data
            failed = false
        } catch {
            failed = coach == nil
        }
    }
}

/// The top of a coach's page: their picture or initials, name and rating,
/// then what they teach and to which levels.
private struct CoachHero: View {
    let coach: Components.Schemas.PublicCoach
    let serverURL: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        BrandContentCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                // The picture above the name at the accessibility sizes, so the
                // name has the card's width («Тодоро/в» broke beside it).
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.m))
                    : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
                layout {
                    BrandAvatar(name: coach.name, url: GameText.picture(coach.avatarUrl, server: serverURL), side: 64)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(CoachText.name(coach.name))
                            .font(Theme.Typography.cardTitle)
                            .accessibilityAddTraits(.isHeader)
                        if let rating = CoachText.rating(coach.rating) {
                            Text(rating)
                                .font(Theme.Typography.cardSubtitle)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !coach.sports.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(String(localized: "coaches.page.teaches"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ChipFlow {
                            ForEach(coach.sports, id: \.sport) { sport in
                                VenueFactChip(text: CoachText.levels(sport))
                            }
                        }
                    }
                    // «Преподава: Падел: нива 2–5, …» as one sentence.
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
