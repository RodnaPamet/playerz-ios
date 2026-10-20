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
            .navigationTitle(String(localized: "coaches.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(String(localized: "coaches.filterLabel"), selection: $sport) {
                            Text(String(localized: "coaches.allSports")).tag(String?.none)
                            ForEach(Sports.known, id: \.self) { sport in
                                Text(GameText.sport(sport)).tag(Optional(sport))
                            }
                        }
                    } label: {
                        Label(String(localized: "coaches.filterLabel"), systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task(id: sport) { await load() }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
        case .failed:
            ContentUnavailableView {
                Text(String(localized: "venues.failed"))
            } actions: {
                Button(String(localized: "venues.retry"), action: retry)
            }
        case .loaded where items.isEmpty:
            ContentUnavailableView(
                sport == nil ? String(localized: "coaches.empty.title") : String(localized: "coaches.empty.sport"),
                systemImage: "figure.tennis",
                description: sport == nil ? Text(String(localized: "coaches.empty.description")) : nil
            )
        case .loaded:
            List {
                Section {
                    ForEach(items, id: \.slug) { coach in
                        NavigationLink {
                            CoachView(slug: coach.slug, session: session)
                        } label: {
                            CoachRow(coach: coach)
                        }
                        .onAppear {
                            if coach.slug == items.last?.slug { Task { await loadMore() } }
                        }
                    }
                } footer: {
                    Text(String(localized: "coaches.intro"))
                }
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
