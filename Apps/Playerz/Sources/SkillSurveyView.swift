import PlayerzAPI
import SwiftUI

/// «Вземи начално ниво» (projectZ#689; questions approved by the owner
/// 2026-11-13): one question at a time, an answer moves on, and the server
/// scores the answers into the level the rating starts from.
struct SkillSurveyView: View {
    let survey: Components.Schemas.SkillSurvey
    /// The answers, scored: the starting level, or nil when refused.
    let submit: ([String: String]) async -> Int?
    let done: () -> Void

    @State private var index = 0
    @State private var answers: [String: String] = [:]
    @State private var stage: Stage = .asking
    @AccessibilityFocusState private var questionFocused: Bool

    enum Stage: Equatable { case asking, sending, result(Int), failed }

    private typealias Question = Components.Schemas.SkillSurvey.questionsPayloadPayload

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .asking: asking
                case .sending:
                    ProgressView(String(localized: "common.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .result(level): result(level)
                case .failed:
                    BrandEmptyState(systemImage: "exclamationmark.triangle", title: String(localized: "survey.failed")) {
                        Button(String(localized: "venues.retry")) { Task { await send() } }
                            .buttonStyle(.brandSecondary(fullWidth: false))
                    }
                }
            }
            .brandPage()
            .navigationTitle(String(localized: "survey.card.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close"), action: done)
                }
                if stage == .asking, index > 0 {
                    ToolbarItem(placement: .navigation) {
                        Button(String(localized: "survey.back")) { index -= 1 }
                    }
                }
            }
        }
    }

    private var asking: some View {
        let question = survey.questions[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(String(localized: "survey.progress \(index + 1) \(survey.questions.count)"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(index + 1), total: Double(survey.questions.count))
                        .tint(Theme.Palette.accentFill)
                        .accessibilityHidden(true)
                }
                Text(Self.text(question.text))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($questionFocused)
                VStack(spacing: Theme.Spacing.m) {
                    ForEach(question.options, id: \.id) { option in
                        let chosen = answers[question.id] == option.id
                        Button {
                            answers[question.id] = option.id
                            next()
                        } label: {
                            HStack {
                                Text(Self.text(option.text))
                                    .font(.body.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: Theme.Spacing.s)
                                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(chosen ? Theme.Palette.accentText : Color.secondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(Theme.Spacing.l)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                            .background(Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.row))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.row)
                                    .strokeBorder(chosen ? Theme.Palette.accentFill : Theme.Palette.hairline, lineWidth: chosen ? 2 : 1)
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(chosen ? .isSelected : [])
                    }
                }
            }
            .padding(Theme.Spacing.l)
        }
        .id(index)
    }

    private func result(_ level: Int) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Text(String(localized: "survey.result.title"))
                .font(Theme.Typography.sectionTitle)
            Text("\(level)")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Palette.accentText)
                .accessibilityLabel(String(localized: "survey.result.spoken \(level)"))
            Text(String(localized: "survey.result.hint"))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button(String(localized: "survey.done"), action: done)
                .buttonStyle(.brandPrimary)
        }
        .padding(Theme.Spacing.xl)
    }

    private func next() {
        if index + 1 < survey.questions.count {
            index += 1
            questionFocused = true
        } else {
            Task { await send() }
        }
    }

    private func send() async {
        stage = .sending
        if let level = await submit(answers) {
            stage = .result(level)
        } else {
            stage = .failed
        }
    }

    /// The question or answer in the app's language.
    private static func text(_ text: Components.Schemas.SurveyText) -> String {
        AppLanguageChoice.current == .en ? text.en : text.bg
    }
}
