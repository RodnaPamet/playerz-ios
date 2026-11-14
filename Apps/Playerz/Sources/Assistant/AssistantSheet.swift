import CoreLocation
import PlayerzAPI
import SwiftUI

/// The assistant's conversation, over the screen it was opened from: half
/// the screen at first, so the screen stays in view.
///
/// It does not drive the app. An answer is text; a booking or a game it
/// prepared is a button that opens the usual booking screen, filled, where
/// the person confirms it. Nothing is booked from here.
struct AssistantSheet: View {
    let store: AssistantStore
    @Bindable var session: SessionModel
    /// Where the question is asked from; nil from a past conversation.
    let page: AssistantPage?
    /// A prepared booking or game the person chose to open: the presenter
    /// closes this sheet and opens it.
    var open: (AssistantProposal) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        if store.earlierLeftOut {
                            Text(AssistantText.earlierLeftOut)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if store.turns.isEmpty {
                            intro
                        }
                        ForEach(store.turns) { turn in
                            AssistantTurnView(turn: turn, offersGames: session.modules.openPlay, open: open)
                                .id(turn.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.turns) {
                    guard let last = store.turns.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .background(Theme.Palette.page.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .navigationTitle(AssistantText.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
                // A fresh conversation: the next question no longer follows
                // the ones on screen. The server keeps them all.
                if !store.turns.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(AssistantText.newConversation, systemImage: "square.and.pencil") {
                            store.newConversation()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onDisappear { store.stop() }
        // Off on this server, or not for this account: the button goes.
        .onChange(of: store.unavailable) { _, refused in
            session.noticeAssistant(refused)
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Palette.accentText)
                .accessibilityHidden(true)
            Text(AssistantText.intro)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
            TextField(AssistantText.prompt, text: Bindable(store).draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($typing)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background(Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.row))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
                .accessibilityLabel(AssistantText.prompt)
            Button {
                send()
            } label: {
                Group {
                    if store.asking {
                        ProgressView()
                    } else {
                        Label(AssistantText.ask, systemImage: "arrow.up.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .foregroundStyle(store.canSend ? Theme.Palette.accentText : Theme.Palette.muted)
                    }
                }
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                .contentShape(Rectangle())
            }
            .disabled(!store.canSend)
            .accessibilityLabel(AssistantText.ask)
            .accessibilityInputLabels([AssistantText.ask, "Попитай", "Ask"])
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Palette.page)
        .overlay(alignment: .top) { Theme.Palette.hairline.frame(height: 0.5) }
    }

    private func send() {
        store.send(page: page, location: Self.knownLocation())
    }

    /// Where the person is, only when the app may already read it: the
    /// question never asks for the permission. The last fix iOS holds; none
    /// is sent when there is none.
    static func knownLocation() -> (lat: Double, lng: Double)? {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            guard let here = manager.location?.coordinate, CLLocationCoordinate2DIsValid(here) else { return nil }
            return (here.latitude, here.longitude)
        default:
            return nil
        }
    }
}

/// One question and what came of it.
private struct AssistantTurnView: View {
    let turn: AssistantStore.Turn
    /// «Игри» is on: a prepared game can be opened.
    let offersGames: Bool
    let open: (AssistantProposal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // The question, on the right, as a sent message is.
            let question = turn.question ?? AssistantText.earlierQuestion
            Text(question)
                .font(.body)
                .foregroundStyle(turn.question == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.Palette.onAccent))
                .padding(.horizontal, Theme.Spacing.m + 2)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background {
                    if turn.question == nil {
                        RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.Palette.hairline)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.row).fill(Theme.Palette.actionFill)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, Theme.Spacing.xl * 2)
                .accessibilityLabel(AssistantText.you(question))

            switch turn.phase {
            case let .working(work):
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView()
                    Text(AssistantText.work(work)).foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            case let .answered(text, proposal, notes):
                AssistantAnswerView(text: text)
                if let proposal, proposal.kind == .booking || offersGames {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Button {
                            open(proposal)
                        } label: {
                            Label(AssistantText.open(proposal.kind),
                                  systemImage: proposal.kind == .game ? "person.3" : "calendar.badge.plus")
                        }
                        .buttonStyle(.brandPrimary(fullWidth: false))
                        Text(AssistantText.preparedNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Label(AssistantText.note(note), systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case let .unanswered(ending):
                Label(AssistantText.ending(ending), systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
