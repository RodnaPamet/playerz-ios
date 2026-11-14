import Foundation

/// The assistant's answer as BLOCKS: paragraphs, headings, lists and tables.
///
/// The server calls the answer plain text, and the model still writes a list
/// or a table now and then; SwiftUI's `Text` draws only inline Markdown, so a
/// table reached Agrent's owner as rows of «|» (2026-11-01). This reads the
/// block structure the model actually uses; anything not recognised stays a
/// paragraph, so a shape this does not know costs formatting, never words.
public enum AssistantAnswer {
    public enum Block: Equatable, Sendable {
        case paragraph(String)
        case heading(String)
        case bullets([String])
        case numbered([String])
        /// The header's cells, then each row's; rows as wide as the header.
        case table(header: [String], rows: [[String]])
        /// `---`, `***` or `___` on its own line.
        case divider
    }

    public static func blocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0

        func flushParagraph() {
            let joined = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { blocks.append(.paragraph(joined)) }
            paragraph = []
        }

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                index += 1
            } else if isRule(line) {
                flushParagraph()
                blocks.append(.divider)
                index += 1
            } else if line.hasPrefix("|") {
                flushParagraph()
                var tableLines: [String] = []
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[index].trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(table(tableLines))
            } else if let heading = heading(line) {
                flushParagraph()
                blocks.append(.heading(heading))
                index += 1
            } else if bullet(line) != nil {
                flushParagraph()
                var items: [String] = []
                while index < lines.count, let item = bullet(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.bullets(items))
            } else if numbered(line) != nil {
                flushParagraph()
                var items: [String] = []
                while index < lines.count, let item = numbered(lines[index].trimmingCharacters(in: .whitespaces)) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.numbered(items))
            } else {
                paragraph.append(line)
                index += 1
            }
        }
        flushParagraph()
        return blocks
    }

    /// `| a | b |` rows; the `|---|---|` rule under the header is dropped.
    /// Short rows are padded and long ones cut to the header's width, so a
    /// row the model got wrong still lines up. No rule means no header: the
    /// first row is a row like the rest, under an empty header.
    private static func table(_ lines: [String]) -> Block {
        let rows = lines.map(cells)
        let isRule: ([String]) -> Bool = { cells in
            !cells.isEmpty && cells.allSatisfy { $0.allSatisfy { "-:".contains($0) } && !$0.isEmpty }
        }
        let header: [String]
        var body: [[String]]
        if rows.count >= 2, isRule(rows[1]) {
            header = rows[0]
            body = Array(rows.dropFirst(2))
        } else {
            header = Array(repeating: "", count: rows.map(\.count).max() ?? 0)
            body = rows
        }
        body = body.filter { !isRule($0) }.map { row in
            Array((row + Array(repeating: "", count: max(0, header.count - row.count))).prefix(header.count))
        }
        return .table(header: header, rows: body)
    }

    /// Three or more of one of `-`, `*`, `_`, spaces allowed between.
    private static func isRule(_ line: String) -> Bool {
        let marks = line.filter { $0 != " " }
        guard marks.count >= 3, let first = marks.first, "-*_".contains(first) else { return false }
        return marks.allSatisfy { $0 == first }
    }

    private static func cells(_ line: String) -> [String] {
        var inner = line
        if inner.hasPrefix("|") { inner.removeFirst() }
        if inner.hasSuffix("|") { inner.removeLast() }
        return inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func heading(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let text = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func bullet(_ line: String) -> String? {
        for mark in ["- ", "* ", "• "] where line.hasPrefix(mark) {
            return String(line.dropFirst(mark.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func numbered(_ line: String) -> String? {
        // One or two digits: «2026. Годината…» is a sentence, not item 2026.
        guard let dot = line.firstIndex(where: { $0 == "." || $0 == ")" }),
              (1...2).contains(line[..<dot].count), line[..<dot].allSatisfy(\.isNumber) else { return nil }
        let rest = line[line.index(after: dot)...]
        guard rest.first == " " else { return nil }
        return rest.trimmingCharacters(in: .whitespaces)
    }

    /// The answer as words, for VoiceOver: no Markdown marks, no pipes, a
    /// table row as its cells.
    public static func spoken(_ text: String) -> String {
        blocks(text).map { block -> String in
            switch block {
            case .paragraph(let words), .heading(let words):
                return plain(words)
            case .bullets(let items), .numbered(let items):
                return items.map(plain).joined(separator: ". ")
            case .table(_, let rows):
                return rows.map { $0.map(plain).filter { !$0.isEmpty }.joined(separator: ", ") }.joined(separator: ". ")
            case .divider:
                return ""
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    /// One block's words without their Markdown marks.
    public static func plain(_ markdown: String) -> String {
        String(inline(markdown).characters)
    }

    /// Inline Markdown (bold, italics) kept, links kept as their words: a
    /// link in an answer opens nothing here.
    public static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        guard var rendered = try? AttributedString(markdown: text, options: options) else {
            return AttributedString(text)
        }
        for run in rendered.runs where run.link != nil {
            rendered[run.range].link = nil
        }
        return rendered
    }
}

/// A server sentence (`refusal.message`, `halt.message`, an error's
/// `message`) is shown only in the app's own language: the server writes it
/// in the ACCOUNT's, which can differ, and a Bulgarian screen never shows
/// English prose. Mostly Cyrillic letters read as Bulgarian.
public enum ServerSentence {
    public static func fits(_ message: String?, bulgarian: Bool) -> Bool {
        guard let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let letters = message.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let cyrillic = letters.filter { (0x0400...0x04FF).contains($0.value) }.count
        let mostlyCyrillic = cyrillic * 2 > letters.count
        return bulgarian ? mostlyCyrillic : !mostlyCyrillic
    }
}
