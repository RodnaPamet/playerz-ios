import PlayerzAPI
import SwiftUI

/// «Какво помни асистентът», from «Настройки»: two halves, as on the web,
/// each with its own controls, because they delete different things.
/// «Запомнено» is what the assistant has concluded about the person, which a
/// tap corrects; «Минали разговори» are the exchanges, which a tap opens to
/// read and continue. Forgetting a conversation keeps what was learned from
/// it, and the reverse, so each «Изтрий всички…» says what it leaves.
///
/// One row goes on a swipe, with a few seconds of «Отмени»; all of a half go
/// after one question.
struct AssistantMemoryView: View {
    @Bindable var session: SessionModel

    @State private var points: AssistantMemoryStore
    @State private var conversations: PastConversationsStore
    @State private var editing: AssistantMemory.Point?
    @State private var confirmingPoints = false
    @State private var confirmingConversations = false
    /// A past conversation opened to read and continue.
    @State private var reading: AssistantMemory.Conversation?
    /// A draft chosen in it, opened once its sheet has gone.
    @State private var pending: AssistantProposal?
    @State private var proposal: ProposalItem?

    init(session: SessionModel) {
        self.session = session
        let client: @MainActor () async throws -> Client = { [weak session] in
            guard let client = await session?.client() else { throw AssistantMemoryError.signedOut }
            return client
        }
        _points = State(initialValue: AssistantMemoryStore(api: .init(
            list: { try await AssistantAPI.points(client: client()) },
            forget: { try await AssistantAPI.forgetPoint($0, client: client()) },
            forgetAll: { try await AssistantAPI.forgetAllPoints(client: client()) },
            edit: { try await AssistantAPI.editPoint($0, text: $1, client: client()) }
        )))
        _conversations = State(initialValue: PastConversationsStore(api: .init(
            list: { try await AssistantAPI.conversations(client: client()) },
            forget: { try await AssistantAPI.deleteConversation($0, client: client()) },
            forgetAll: { try await AssistantAPI.deleteAllConversations(client: client()) }
        )))
    }

    var body: some View {
        List {
            pointsSection
            conversationsSection
        }
        .listStyle(.insetGrouped)
        .brandPage()
        .navigationTitle(AssistantMemoryText.title)
        .brandHeader(.back(AssistantMemoryText.title))
        .task { await loadBoth() }
        .refreshable { await loadBoth() }
        .onDisappear {
            points.flush()
            conversations.flush()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if let point = points.undoable {
                    undoBar(AssistantMemoryText.forgotten(point)) { points.undo() }
                }
                if let conversation = conversations.undoable {
                    undoBar(AssistantMemoryText.deleted(conversation)) { conversations.undo() }
                }
            }
        }
        .sheet(item: $editing) { point in
            AssistantMemoryEditView(point: point, store: points)
        }
        .sheet(item: $reading, onDismiss: {
            // Continued, it is newer and longer now; and what it taught the
            // assistant may be among the points.
            Task { await loadBoth() }
            if let pending {
                proposal = ProposalItem(proposal: pending)
                self.pending = nil
            }
        }) { conversation in
            PastConversationSheet(conversation: conversation, session: session) { draft in
                pending = draft
                reading = nil
            }
            .outsideShellBar()
        }
        .sheet(item: $proposal) { item in
            AssistantProposalFlow(proposal: item.proposal, session: session).outsideShellBar()
        }
        .confirmationDialog(AssistantMemoryText.forgetAllQuestion, isPresented: $confirmingPoints,
                            titleVisibility: .visible) {
            Button(AssistantMemoryText.forgetAll, role: .destructive) {
                Task { await points.forgetAll() }
            }
            Button(AssistantMemoryText.cancel, role: .cancel) {}
        } message: {
            Text(AssistantMemoryText.forgetAllNote)
        }
        .confirmationDialog(AssistantMemoryText.deleteAllQuestion, isPresented: $confirmingConversations,
                            titleVisibility: .visible) {
            Button(AssistantMemoryText.deleteAll, role: .destructive) {
                Task { await conversations.forgetAll() }
            }
            Button(AssistantMemoryText.cancel, role: .cancel) {}
        } message: {
            Text(AssistantMemoryText.deleteAllNote)
        }
        .alert(AssistantMemoryText.notForgotten, isPresented: failureShown, presenting: failure) { _ in
            Button(String(localized: "common.close"), role: .cancel) { clearFailure() }
        } message: { failure in
            Text(AssistantMemoryText.problem(failure))
        }
    }

    private func loadBoth() async {
        async let remembered: Void = points.load()
        async let exchanged: Void = conversations.load()
        _ = await (remembered, exchanged)
        // Switched off meanwhile: the row in «Настройки» and the button go.
        if points.state == .failed(.disabled) { session.noticeAssistant(.disabled) }
    }

    private var failure: AssistantMemoryError? { points.failure ?? conversations.failure }

    private var failureShown: Binding<Bool> {
        Binding { failure != nil } set: { if !$0 { clearFailure() } }
    }

    private func clearFailure() {
        points.failure = nil
        conversations.failure = nil
    }

    // MARK: - «Запомнено»

    private var pointsSection: some View {
        Section {
            switch points.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity)
            case let .failed(problem):
                failed(problem) { await points.load() }
            case .loaded where points.items.isEmpty:
                empty(AssistantMemoryText.emptyTitle, AssistantMemoryText.emptyNote)
            case .loaded:
                ForEach(points.items) { point in
                    Button { editing = point } label: { pointRow(point) }
                        .buttonStyle(.plain)
                        .accessibilityHint(AssistantMemoryText.editHint)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteButton { forget(point, in: points) }
                        }
                }
                forgetAllButton(AssistantMemoryText.forgetAll) { confirmingPoints = true }
            }
        } header: {
            Text(AssistantMemoryText.listTitle)
        } footer: {
            Text(AssistantMemoryText.listNote)
        }
        .brandListRow()
    }

    private func pointRow(_ point: AssistantMemory.Point) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(point.text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(meta(point))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func meta(_ point: AssistantMemory.Point) -> String {
        let day = AssistantMemoryText.rememberedOn(point.rememberedAt.formatted(date: .long, time: .omitted))
        return point.editedByPerson ? "\(day) · \(AssistantMemoryText.editedByYou)" : day
    }

    // MARK: - «Минали разговори»

    private var conversationsSection: some View {
        Section {
            switch conversations.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity)
            case let .failed(problem):
                failed(problem) { await conversations.load() }
            case .loaded where conversations.items.isEmpty:
                empty(AssistantMemoryText.noConversations, AssistantMemoryText.noConversationsNote)
            case .loaded:
                ForEach(conversations.items) { conversation in
                    Button { reading = conversation } label: { conversationRow(conversation) }
                        .buttonStyle(.plain)
                        .accessibilityHint(AssistantMemoryText.openHint)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            deleteButton { forget(conversation, in: conversations) }
                        }
                }
                forgetAllButton(AssistantMemoryText.deleteAll) { confirmingConversations = true }
            }
        } header: {
            Text(AssistantMemoryText.conversationsTitle)
        } footer: {
            Text(AssistantMemoryText.conversationsNote)
        }
        .brandListRow()
    }

    /// The person's first question, then when and how long.
    private func conversationRow(_ conversation: AssistantMemory.Conversation) -> some View {
        let opening = conversation.opening.map { "«\($0)»" } ?? AssistantMemoryText.noOpening
        let when = conversation.lastTurnAt.formatted(date: .abbreviated, time: .omitted)
        let turns = AssistantMemoryText.turns(conversation.turns)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(opening)
                .font(.body)
                .foregroundStyle(conversation.opening == nil ? .secondary : .primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(when) · \(turns)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(opening), \(when), \(turns)")
    }

    // MARK: - Shared rows

    private func deleteButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(AssistantMemoryText.delete, systemImage: "trash")
        }
    }

    private func forgetAllButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .foregroundStyle(Theme.Palette.danger)
        }
    }

    private func empty(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func failed(_ problem: AssistantMemoryError, retry: @escaping @MainActor () async -> Void) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(AssistantMemoryText.problem(problem))
                .font(.footnote)
                .foregroundStyle(Theme.Palette.danger)
                .fixedSize(horizontal: false, vertical: true)
            Button(AssistantMemoryText.retry) { Task { await retry() } }
        }
    }

    /// Swiped: gone from the list, said with the way back, and forgotten when
    /// the window closes, longer under VoiceOver or Switch Control.
    private func forget<Item>(_ item: Item, in store: ForgettableList<Item>) {
        let assisted = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        store.forget(item, window: assisted ? ForgettableList<Item>.assistedWindow : nil)
        var said = AttributedString(AssistantMemoryText.forgottenSaid)
        said.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(said).post()
    }

    private func undoBar(_ sentence: String, undo: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text(sentence)
                .font(.subheadline)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(AssistantMemoryText.undo, action: undo)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card)
        .overlay(alignment: .top) { Theme.Palette.hairline.frame(height: 0.5) }
    }
}

/// Correcting one point: the person's own words, which the assistant then
/// never rewrites.
private struct AssistantMemoryEditView: View {
    let point: AssistantMemory.Point
    let store: AssistantMemoryStore

    @State private var text: String
    @State private var saving = false
    @State private var refusal: AssistantMemoryError?
    @Environment(\.dismiss) private var dismiss

    init(point: AssistantMemory.Point, store: AssistantMemoryStore) {
        self.point = point
        self.store = store
        _text = State(initialValue: point.text)
    }

    private let limit = AssistantMemory.Point.maxLength

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AssistantMemoryText.editPlaceholder, text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: text) { _, now in
                            if now.count > limit { text = String(now.prefix(limit)) }
                        }
                } footer: {
                    if let refusal {
                        Text(AssistantMemoryText.problem(refusal)).foregroundStyle(Theme.Palette.danger)
                    } else {
                        Text(AssistantMemoryText.editCount(text.count, limit))
                    }
                }
                .brandListRow()
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.page.ignoresSafeArea())
            .navigationTitle(AssistantMemoryText.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AssistantMemoryText.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AssistantMemoryText.save) { Task { await save() } }
                        .disabled(saving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if let refusal = await store.edit(point, to: text) {
            self.refusal = refusal
        } else {
            dismiss()
        }
    }
}
