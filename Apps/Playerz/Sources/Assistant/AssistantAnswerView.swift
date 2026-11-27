import PlayerzAPI
import SwiftUI

/// The answer's blocks, drawn: a two-column table as label-and-value rows, a
/// wider one as a card per row, a list with its marks.
struct AssistantAnswerView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(Array(AssistantAnswer.blocks(text).enumerated()), id: \.offset) { _, block in
                view(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AssistantText.answered(AssistantAnswer.spoken(text)))
    }

    @ViewBuilder
    private func view(_ block: AssistantAnswer.Block) -> some View {
        switch block {
        case let .paragraph(words):
            inline(words).font(.body)
        case let .heading(words):
            inline(words).font(.headline)
        case let .bullets(items):
            list(items.map { ("•", $0) })
        case let .numbered(items):
            list(items.enumerated().map { ("\($0.offset + 1).", $0.element) })
        case let .table(header, rows):
            table(header: header, rows: rows)
        case .divider:
            Divider().overlay(Theme.Palette.hairline).padding(.vertical, Theme.Spacing.xs)
        }
    }

    private func inline(_ markdown: String) -> some View {
        Text(AssistantAnswer.inline(markdown))
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private func list(_ items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(item.0).foregroundStyle(.secondary)
                    inline(item.1)
                }
                .font(.body)
            }
        }
    }

    /// Two columns: label and value. More: a card per row, its first cell
    /// the title, the rest «header: value» under it. Either way it reads at
    /// any text size, where a grid of narrow columns would break every word.
    private func table(header: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if header.count == 2, header.contains(where: { !$0.isEmpty }) {
                HStack(alignment: .firstTextBaseline) {
                    inline(header[0])
                    Spacer(minLength: Theme.Spacing.m)
                    inline(header[1])
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, Theme.Spacing.xs)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().overlay(Theme.Palette.hairline) }
                if row.count == 2 {
                    HStack(alignment: .firstTextBaseline) {
                        inline(row[0])
                        Spacer(minLength: Theme.Spacing.m)
                        inline(row[1]).font(.body.monospacedDigit()).multilineTextAlignment(.trailing)
                    }
                    .font(.body)
                    .padding(.vertical, Theme.Spacing.xs + 2)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = row.first { inline(title).font(.body.weight(.semibold)) }
                        ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { column, cell in
                            if !cell.isEmpty {
                                let name = header.indices.contains(column + 1) ? header[column + 1] : ""
                                inline(name.isEmpty ? cell : "\(name): \(cell)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs + 2)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs + 2)
        .background(Theme.Palette.card, in: .rect(cornerRadius: Theme.Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.tile).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }
}
