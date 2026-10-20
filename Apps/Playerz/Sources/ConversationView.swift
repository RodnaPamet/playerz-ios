import PlayerzAPI
import SwiftUI

/// One conversation (#484): the messages, the composer, and the answer to a
/// request, a block or a report.
struct ConversationView: View {
    @Bindable var session: SessionModel
    @State private var model: ConversationModel
    @State private var draft = ""
    @State private var retracting: Components.Schemas.Message?
    @State private var confirmingRetract = false
    @State private var reporting: ConversationModel.Reported?

    init(conversationId: String, session: SessionModel) {
        self.session = session
        _model = State(initialValue: ConversationModel(conversationId: conversationId))
    }

    var body: some View {
        Group {
            if let conversation = model.conversation {
                thread(conversation)
            } else if model.failed {
                ContentUnavailableView {
                    Text(String(localized: "messages.conversationFailed"))
                } actions: {
                    Button(String(localized: "venues.retry")) { Task { await model.load(session) } }
                }
            } else {
                ProgressView(String(localized: "common.loading"))
            }
        }
        .navigationTitle(model.conversation.map { ConversationText.title($0.counterpart) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .task {
            await model.load(session)
            await model.poll(session)
        }
        .onChange(of: model.problem) { _, text in
            if let text { AccessibilityNotification.Announcement(text).post() }
        }
        .confirmationDialog(
            String(localized: "messages.retractTitle"),
            isPresented: $confirmingRetract,
            titleVisibility: .visible,
            presenting: retracting
        ) { message in
            Button(String(localized: "messages.retract"), role: .destructive) {
                Task { await model.retract(message.id, session) }
            }
            Button(String(localized: "messages.cancel"), role: .cancel) {}
        } message: { _ in
            Text(String(localized: "messages.retractBody"))
        }
        .sheet(item: $reporting) { what in
            ReportSheet(title: String(localized: "messages.report")) { reason, details in
                await model.report(what, reason: reason, details: details, session)
            } done: {
                reporting = nil
            }
        }
    }

    // ─── The thread ───────────────────────────────────────────────────

    private func thread(_ conversation: Components.Schemas.Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.olderCursor != nil {
                        Button(String(localized: "messages.older")) {
                            Task { await model.loadOlder(session) }
                        }
                        .buttonStyle(.bordered)
                    }
                    if model.messages.isEmpty {
                        Text(String(localized: "messages.none"))
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                    ForEach(model.messages, id: \.id) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .contextMenu { messageActions(message) }
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: model.messages.last?.id) { _, last in
                if let last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom) { footer(conversation) }
        }
    }

    @ViewBuilder private func messageActions(_ message: Components.Schemas.Message) -> some View {
        if message.mine && !message.deleted {
            Button(String(localized: "messages.retract"), systemImage: "trash", role: .destructive) {
                retracting = message
                confirmingRetract = true
            }
        } else if !message.mine && !message.deleted {
            Button(String(localized: "messages.report"), systemImage: "exclamationmark.bubble") {
                reporting = .message(message.id)
            }
        }
    }

    /// The state's note, the request's answer, and the composer when it may send.
    @ViewBuilder private func footer(_ conversation: Components.Schemas.Conversation) -> some View {
        let name = ConversationText.title(conversation.counterpart)
        VStack(spacing: 8) {
            if let problem = model.problem {
                Text(problem).font(.footnote).foregroundStyle(.red)
            }
            switch conversation.state {
            case .request:
                Text(String(localized: "messages.notice.request \(name)")).font(.footnote)
                HStack {
                    Button(String(localized: "messages.accept")) {
                        Task { await model.answer(accept: true, session) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button(String(localized: "messages.decline")) {
                        Task { await model.answer(accept: false, session) }
                    }
                    .buttonStyle(.bordered)
                }
            case .pending:
                Text(String(localized: "messages.notice.pending \(name)")).font(.footnote)
            case .declined:
                Text(String(localized: "messages.notice.declined")).font(.footnote)
            case .blocked:
                Text(conversation.blockedByMe
                     ? String(localized: "messages.notice.blockedByMe \(name)")
                     : String(localized: "messages.notice.blocked"))
                    .font(.footnote)
            case .closed:
                Text(String(localized: "messages.notice.closed")).font(.footnote)
            case .active:
                EmptyView()
            }
            if conversation.canSend {
                composer
            }
        }
        .foregroundStyle(.primary)
        .padding()
        .background(.bar)
    }

    private var composer: some View {
        HStack(alignment: .bottom) {
            TextField(String(localized: "messages.placeholder"), text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
            Button(String(localized: "messages.send"), systemImage: "arrow.up.circle.fill") {
                Task {
                    if await model.send(draft, session) { draft = "" }
                }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .disabled(model.sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      || draft.count > model.maxLength)
        }
    }

    @ToolbarContentBuilder private var menu: some ToolbarContent {
        if let conversation = model.conversation {
            ToolbarItem(placement: .topBarTrailing) {
                Menu(String(localized: "messages.more"), systemImage: "ellipsis.circle") {
                    // A game chat is reported, not blocked (#376).
                    if conversation.kind == .player, conversation.state != .closed {
                        Button(conversation.blockedByMe
                               ? String(localized: "messages.unblock")
                               : String(localized: "messages.block")) {
                            Task { await model.setBlocked(!conversation.blockedByMe, session) }
                        }
                    }
                    Button(String(localized: "messages.report"), role: .destructive) {
                        reporting = .conversation
                    }
                }
            }
        }
    }
}

/// One message: mine on the right; a club's reply named for the club; a
/// retracted one as a note.
private struct MessageBubble: View {
    let message: Components.Schemas.Message

    var body: some View {
        HStack {
            if message.mine { Spacer(minLength: 40) }
            VStack(alignment: message.mine ? .trailing : .leading, spacing: 2) {
                if !message.mine {
                    Text(sender).font(.caption).foregroundStyle(.secondary)
                }
                Text(message.deleted ? String(localized: "messages.retracted") : (message.body ?? ""))
                    .italic(message.deleted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.mine ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.fill.tertiary),
                        in: .rect(cornerRadius: 14)
                    )
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !message.mine { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }

    private var sender: String {
        if message.fromClub, let club = message.sender.clubName { return club }
        if message.sender.deleted { return String(localized: "messages.deletedUser") }
        return message.sender.name ?? String(localized: "messages.unnamed")
    }
}
