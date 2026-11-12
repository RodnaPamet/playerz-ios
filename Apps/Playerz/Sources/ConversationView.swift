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
                BrandEmptyState(systemImage: "wifi.exclamationmark", title: String(localized: "messages.conversationFailed")) {
                    Button(String(localized: "venues.retry")) { Task { await model.load(session) } }
                        .buttonStyle(.brandSecondary(fullWidth: false))
                }
            } else {
                ProgressView(String(localized: "common.loading"))
            }
        }
        .brandPage()
        // Hidden with the system bar; still what VoiceOver calls the screen.
        .navigationTitle(title)
        // Pushed, it goes back; first in a sheet (ConversationSheet), it closes it.
        .brandHeader(.back(title)) { menu }
        // The bottom of this screen is the composer.
        .floatingTabBarHidden()
        .task {
            await model.load(session)
            // A DEBUG launch can look at the report sheet (`PLAYERZ_OPEN=report`).
            if DebugLaunch.open == "report", model.conversation != nil { reporting = .conversation }
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
        .brandSheet(item: $reporting, detents: [.medium, .large]) { what in
            ReportSheet(title: String(localized: "messages.report")) { reason, details in
                await model.report(what, reason: reason, details: details, session)
            } done: {
                reporting = nil
            }
        }
    }

    private var title: String {
        model.conversation.map { ConversationText.title($0.counterpart) } ?? ""
    }

    // ─── The thread ───────────────────────────────────────────────────

    private func thread(_ conversation: Components.Schemas.Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.s) {
                    if model.olderCursor != nil {
                        Button(String(localized: "messages.older")) {
                            Task { await model.loadOlder(session) }
                        }
                        .buttonStyle(.brandSecondary(fullWidth: false))
                    }
                    if model.messages.isEmpty {
                        Text(String(localized: "messages.none"))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                    }
                    ForEach(model.messages, id: \.id) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .contextMenu { messageActions(message) }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.l)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: model.messages.last?.id) { _, last in
                if let last { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer(conversation) }
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
        VStack(spacing: Theme.Spacing.s) {
            if let problem = model.problem {
                Text(problem).font(.footnote).foregroundStyle(Theme.Palette.danger)
            }
            switch conversation.state {
            case .request:
                Text(String(localized: "messages.notice.request \(name)")).font(.footnote)
                HStack {
                    Button(String(localized: "messages.accept")) {
                        Task { await model.answer(accept: true, session) }
                    }
                    .buttonStyle(.brandPrimary(fullWidth: false))
                    Button(String(localized: "messages.decline")) {
                        Task { await model.answer(accept: false, session) }
                    }
                    .buttonStyle(.brandSecondary(fullWidth: false))
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
        .multilineTextAlignment(.center)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.Palette.page.ignoresSafeArea())
        .overlay(alignment: .top) { Divider().overlay(Theme.Palette.hairline) }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            TextField(String(localized: "messages.placeholder"), text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .frame(minHeight: Theme.minTarget)
                .background(Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.row))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.Palette.hairline))
            Button {
                Task {
                    if await model.send(draft, session) { draft = "" }
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(width: sendDiameter, height: sendDiameter)
                    .background(Theme.Palette.accentFill, in: .circle)
            }
            .buttonStyle(.plain)
            .opacity(canSend ? 1 : 0.45)
            .disabled(!canSend)
            .accessibilityLabel(String(localized: "messages.send"))
        }
    }

    /// Grows with the text, to a point: at the largest sizes the field needs the width.
    @ScaledMetric(relativeTo: .body) private var sendSide: CGFloat = 44
    private var sendDiameter: CGFloat { min(sendSide, 66) }

    private var canSend: Bool {
        !model.sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.count <= model.maxLength
    }

    @ViewBuilder private var menu: some View {
        if let conversation = model.conversation {
            BrandHeaderMenuButton(label: String(localized: "messages.more")) {
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
                    .foregroundStyle(message.mine && !message.deleted ? Theme.Palette.onAccent : Color.primary)
                    .padding(.horizontal, Theme.Spacing.m + 2)
                    .padding(.vertical, Theme.Spacing.s + 2)
                    .background(bubble, in: .rect(cornerRadius: Theme.Radius.row))
                    .overlay {
                        // Someone else's on the card colour: the hairline keeps its edge in dark mode.
                        if !message.mine {
                            RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
                        }
                    }
                Text(message.createdAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !message.mine { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
    }

    /// Mine in the accent; a retracted one of mine greyed, as a note.
    private var bubble: Color {
        if message.mine { return message.deleted ? Theme.Palette.chipIdle : Theme.Palette.accentFill }
        return Theme.Palette.card
    }

    private var sender: String {
        if message.fromClub, let club = message.sender.clubName { return club }
        if message.sender.deleted { return String(localized: "messages.deletedUser") }
        return message.sender.name ?? String(localized: "messages.unnamed")
    }
}
