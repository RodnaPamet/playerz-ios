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
    /// A DEBUG launch can open the lesson booking at once (DebugLaunch).
    @State private var debugBook = false

    init(slug: String, session: SessionModel) {
        self.slug = slug
        self.session = session
        _reviews = State(initialValue: CoachReviewsModel(slug: slug))
    }

    var body: some View {
        Group {
            if let coach {
                List {
                    Section {
                        if let rating = CoachText.rating(coach.rating) {
                            Text(rating).foregroundStyle(.secondary)
                        }
                        ForEach(coach.sports, id: \.sport) { sport in
                            Text(CoachText.levels(sport))
                        }
                    } header: {
                        Text(String(localized: "coaches.page.teaches"))
                    }
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
                    if !coach.venues.isEmpty {
                        Section {
                            NavigationLink(String(localized: "coaches.lesson.title")) {
                                LessonBookingView(coach: coach, session: session)
                            }
                        }
                    }
                    CoachReviewsSection(model: reviews, session: session)
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
                .sheet(item: $reviews.reporting) { reported in
                    ReportSheet(title: String(localized: "messages.reportReview")) { reason, details in
                        await reviews.send(report: reported.id, reason: reason, details: details, session)
                    } done: {
                        reviews.reporting = nil
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Text(String(localized: "venues.failed"))
                } actions: {
                    Button(String(localized: "venues.retry"), action: retry)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(coach.map { CoachText.name($0.name) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
            if DebugLaunch.coachBook != nil, coach?.venues.isEmpty == false { debugBook = true }
        }
        .navigationDestination(isPresented: $debugBook) {
            if let coach {
                LessonBookingView(coach: coach, session: session)
            }
        }
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
