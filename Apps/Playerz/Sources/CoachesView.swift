import PlayerzAPI
import SwiftUI

/// «Треньори» (playerz-ios#19), the web's `/coaches`: approved coaches a
/// lesson can be booked with, by sport. Only while the coaches module is on.
struct CoachesView: View {
    @Bindable var session: SessionModel

    @State private var sport: String?
    @State private var items: [Components.Schemas.PublicCoach] = []
    @State private var nextCursor: String?
    @State private var phase: Phase = .loading

    enum Phase { case loading, loaded, failed }

    var body: some View {
        content
            .brandPage()
            // Hidden with the system bar; still what VoiceOver calls the screen.
            .navigationTitle(String(localized: "coaches.title"))
            // The sport filter as the venue's day strip: one tap, always in view.
            .brandChipBar {
                BrandChipRow {
                    BrandChip(String(localized: "coaches.allSports"), isSelected: sport == nil) { sport = nil }
                    ForEach(Sports.known, id: \.self) { item in
                        BrandChip(GameText.sport(item), isSelected: sport == item) { sport = item }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(String(localized: "coaches.filterLabel"))
            }
            .brandHeader(.back(String(localized: "coaches.title")))
            .task(id: sport) { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView(String(localized: "common.loading"))
        case .failed:
            BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "coaches.failed")) {
                Button(String(localized: "venues.retry"), action: retry)
                    .buttonStyle(.brandSecondary(fullWidth: false))
            }
        case .loaded where items.isEmpty:
            BrandEmptyState(
                systemImage: "figure.tennis",
                title: sport == nil ? String(localized: "coaches.empty.title") : String(localized: "coaches.empty.sport"),
                message: sport == nil ? String(localized: "coaches.empty.description") : nil
            )
        case .loaded:
            // Cards on the page, as the clubs' list: each coach opens their page.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text(String(localized: "coaches.intro"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(items, id: \.slug) { coach in
                        NavigationLink {
                            CoachView(slug: coach.slug, session: session)
                        } label: {
                            BrandContentCard {
                                CoachRow(coach: coach, serverURL: session.serverURL)
                            }
                        }
                        .buttonStyle(.brandCard)
                        .onAppear {
                            if coach.slug == items.last?.slug { Task { await loadMore() } }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .refreshable { await load() }
        }
    }

    private func retry() {
        phase = .loading
        Task { await load() }
    }

    private func load() async {
        guard let client = await session.client() else {
            phase = .failed
            return
        }
        do {
            let page = try await client.listCoaches(query: .init(sport: sport)).ok.body.json.data
            items = page.items
            nextCursor = page.nextCursor
            phase = .loaded
        } catch {
            phase = items.isEmpty ? .failed : .loaded
        }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, let client = await session.client() else { return }
        nextCursor = nil
        if let page = try? await client.listCoaches(query: .init(sport: sport, cursor: cursor)).ok.body.json.data {
            items += page.items
            nextCursor = page.nextCursor
        }
    }
}
