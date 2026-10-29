import UIKit

// MarkdownText - Reddit's markdown rendered as an NSAttributedString.
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.MarkdownNode)
// and measured off 3x screenshots of the original: post self text and comment
// bodies are drawn by the same renderer, so both go through here.
//
// Reddit's dialect is a subset of CommonMark plus its own extras. This handles
// the parts that actually appear in comments and self posts:
//
//   * emphasis: **bold**, *italic*, _italic_, ~~strike~~
//   * [text](url) links (drawn in the accent blue) and bare /r/ and /u/ names
//     left as plain text, exactly as Apollo leaves them
//   * `code` spans in a monospaced font
//   * paragraphs separated by blank lines, and single newlines kept as line
//     breaks (Reddit honours them in comments)
//   * > quotes, # headings, and -/* lists
//   * HTML entities, since the API stores &amp; / &lt; / &gt; / &#39; literally
//
// The original also renders tables, embeds and spoiler tags; none of those are
// wired up here yet.
enum MarkdownText {

    /// How a screen draws its body text. Post self text and comment bodies
    /// differ in size and weight, so both are parameters rather than constants.
    struct Style {
        var fontSize: CGFloat
        /// Line height as a multiple of the font size. Measured: Apollo's
        /// comment bodies sit a touch looser than the system default.
        var lineHeightMultiple: CGFloat = 1.2
        var textColor: UIColor = .label
        /// Space after a paragraph, in points.
        var paragraphSpacing: CGFloat = 12
        var boldWeight: UIFont.Weight = .semibold
        var regularWeight: UIFont.Weight = .regular
        var linkColor: UIColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)

        static let comment = Style(fontSize: 15, lineHeightMultiple: 1.2, paragraphSpacing: 12)
        static let postBody = Style(fontSize: 17, lineHeightMultiple: 1.3, paragraphSpacing: 14)
    }

    // MARK: - Rendering

    static func attributedString(_ markdown: String?, style: Style) -> NSAttributedString {
        guard var text = markdown, !text.isEmpty else {
            return NSAttributedString(string: "")
        }
        text = self.unescaped(text)

        let result = NSMutableAttributedString()
        // Reddit separates blocks with blank lines.
        let blocks = text.components(separatedBy: "\n\n")
        for (index, block) in blocks.enumerated() {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if result.length > 0 {
                result.append(NSAttributedString(string: "\n", attributes: self.attributes(style, paragraphSpacing: style.paragraphSpacing)))
            }
            result.append(self.block(trimmed, style: style))
            _ = index
        }
        return result
    }

    /// One block: a quote, a heading, a list, or plain lines.
    private static func block(_ block: String, style: Style) -> NSAttributedString {
        let lines = block.components(separatedBy: "\n")
        var runs: [NSAttributedString] = []

        for (index, rawLine) in lines.enumerated() {
            var line = rawLine
            var lineStyle = style
            var prefix: String? = nil

            // > quotes are drawn grey, the way Apollo dims quoted text.
            if line.hasPrefix(">") {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                lineStyle.textColor = lineStyle.textColor.withAlphaComponent(0.75)
            }

            // # headings are bold and larger (h1/h2 only: Reddit stops there).
            if line.hasPrefix("# ") || line.hasPrefix("## ") {
                let level = line.hasPrefix("## ") ? 2 : 1
                line = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                lineStyle.fontSize = style.fontSize + (level == 1 ? 4 : 2)
            }

            // - and * bullets become a middle dot, which is what the original
            // draws for a list item's marker.
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                line = String(line.dropFirst(2))
                prefix = "\u{2022}\u{2003}"
            }

            if index > 0 {
                runs.append(NSAttributedString(string: "\n", attributes: self.attributes(lineStyle)))
            }
            if let prefix = prefix {
                runs.append(NSAttributedString(string: prefix, attributes: self.attributes(lineStyle)))
            }
            runs.append(self.inline(line, style: lineStyle))
        }

        let result = NSMutableAttributedString()
        for run in runs { result.append(run) }
        return result
    }

    // MARK: - Inline spans

    /// Markers as literal strings, matched character by character. This runs
    /// for every comment body inside Texture's background layout pass, so
    /// nothing here may allocate per step.
    private static let boldMarkers = ["**", "__"]
    private static let strikeMarkers = ["~~"]
    private static let italicMarkers = ["*", "_"]

    /// Bold, italic, strike, code and links inside one line.
    private static func inline(_ line: String, style: Style) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let characters = Array(line)
        var index = 0
        var plain = ""

        func flushPlain() {
            guard !plain.isEmpty else { return }
            result.append(NSAttributedString(string: plain, attributes: self.attributes(style)))
            plain = ""
        }

        while index < characters.count {
            let character = characters[index]

            // [text](url)
            if character == "[", let parsed = self.parseLink(characters, at: index) {
                flushPlain()
                var attributes = self.attributes(style)
                attributes[.link] = parsed.url
                attributes[.foregroundColor] = style.linkColor
                result.append(NSAttributedString(string: parsed.text, attributes: attributes))
                index = parsed.end
                continue
            }

            // `code`
            if character == "`", let end = self.index(of: "`", in: characters,
                                                     from: index + 1, requireNonSpaceBefore: false) {
                flushPlain()
                let code = String(characters[(index + 1)..<end])
                var attributes = self.attributes(style)
                attributes[.font] = UIFont.monospacedSystemFont(ofSize: style.fontSize, weight: .regular)
                attributes[.backgroundColor] = UIColor.systemGray6
                result.append(NSAttributedString(string: code, attributes: attributes))
                index = end + 1
                continue
            }

            // ** bold ** / __ bold __
            if let (marker, end) = self.marker(characters, at: index, candidates: self.boldMarkers),
               let close = self.index(of: marker, in: characters, from: end) {
                flushPlain()
                let inner = self.inline(String(characters[end..<close]), style: style)
                let bold = NSMutableAttributedString(attributedString: inner)
                self.applyBold(to: bold, style: style)
                result.append(bold)
                index = close + marker.count
                continue
            }

            // ~~ strike ~~
            if let (marker, end) = self.marker(characters, at: index, candidates: self.strikeMarkers),
               let close = self.index(of: marker, in: characters, from: end) {
                flushPlain()
                let inner = self.inline(String(characters[end..<close]), style: style)
                let struck = NSMutableAttributedString(attributedString: inner)
                self.applyStrike(to: struck)
                result.append(struck)
                index = close + marker.count
                continue
            }

            // * italic * / _ italic _
            if let (marker, end) = self.marker(characters, at: index, candidates: self.italicMarkers),
               let close = self.index(of: marker, in: characters, from: end) {
                flushPlain()
                let inner = self.inline(String(characters[end..<close]), style: style)
                let italic = NSMutableAttributedString(attributedString: inner)
                self.applyItalic(to: italic, style: style)
                result.append(italic)
                index = close + marker.count
                continue
            }

            // Nothing matched, so this character is literal. Advancing by one
            // is what keeps an unmatched `*`, `_` or `~` (common in jokes,
            // emoticons and URLs) from looping forever.
            plain.append(character)
            index += 1
        }

        flushPlain()
        return result
    }

    /// Does `marker` begin exactly at `index`?
    private static func matches(_ characters: [Character], at index: Int, _ marker: String) -> Bool {
        let length = marker.count
        guard index >= 0, index + length <= characters.count else { return false }
        var offset = 0
        for expected in marker {
            if characters[index + offset] != expected { return false }
            offset += 1
        }
        return true
    }

    /// Matches one of the markers at `index`, returning it and the index just
    /// past it. A markdown marker needs a non-space character right after it.
    private static func marker(_ characters: [Character], at index: Int, candidates: [String]) -> (String, Int)? {
        for candidate in candidates {
            let end = index + candidate.count
            guard end < characters.count, self.matches(characters, at: index, candidate) else { continue }
            let next = characters[end]
            guard next != " ", next != "\n" else { continue }
            return (candidate, end)
        }
        return nil
    }

    /// First occurrence of `marker` at or after `start`. Emphasis closers must
    /// follow a non-space character; links and code fences do not.
    private static func index(of marker: String, in characters: [Character], from start: Int,
                              requireNonSpaceBefore: Bool = true) -> Int? {
        let length = marker.count
        guard length > 0, start >= 0, start + length <= characters.count else { return nil }
        guard let first = marker.first else { return nil }
        var index = start
        while index + length <= characters.count {
            if characters[index] == first, self.matches(characters, at: index, marker) {
                if !requireNonSpaceBefore || (index > 0 && characters[index - 1] != " ") {
                    return index
                }
            }
            index += 1
        }
        return nil
    }

    /// Parses `[text](url)` starting at the opening bracket.
    private static func parseLink(_ characters: [Character], at index: Int) -> (text: String, url: URL?, end: Int)? {
        guard let closeBracket = self.index(of: "]", in: characters,
                                           from: index + 1, requireNonSpaceBefore: false),
              closeBracket + 1 < characters.count,
              characters[closeBracket + 1] == "(",
              let closeParen = self.index(of: ")", in: characters,
                                      from: closeBracket + 2, requireNonSpaceBefore: false) else { return nil }
        let text = String(characters[(index + 1)..<closeBracket])
        var destination = String(characters[(closeBracket + 2)..<closeParen])
        // Reddit escapes parentheses inside URLs.
        destination = destination.replacingOccurrences(of: "\\(", with: "(")
            .replacingOccurrences(of: "\\)", with: ")")
        // Apollo resolves relative Reddit paths (/r/…, /u/…) against reddit.com.
        let url: URL?
        if destination.hasPrefix("/") {
            url = URL(string: "https://www.reddit.com" + destination)
        } else {
            url = URL(string: destination)
        }
        return (text, url, closeParen + 1)
    }

    // MARK: - Attributes

    private static func attributes(_ style: Style, paragraphSpacing: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        // `lineHeightMultiple` scales the FONT's leading, not the point size,
        // so set the line height explicitly: a 15pt body must pitch 18pt (1.2)
        // the way the original's does, and the multiplier alone gave 21.5pt.
        let lineHeight = style.fontSize * style.lineHeightMultiple
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.lineHeightMultiple = 1.0
        paragraph.paragraphSpacing = paragraphSpacing
        return [
            .font: UIFont.systemFont(ofSize: style.fontSize, weight: style.regularWeight),
            .foregroundColor: style.textColor,
            .paragraphStyle: paragraph
        ]
    }

    private static func applyBold(to string: NSMutableAttributedString, style: Style) {
        string.enumerateAttribute(.font, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            let size = (value as? UIFont)?.pointSize ?? style.fontSize
            string.addAttribute(.font, value: UIFont.systemFont(ofSize: size, weight: style.boldWeight), range: range)
        }
    }

    private static func applyItalic(to string: NSMutableAttributedString, style: Style) {
        string.enumerateAttribute(.font, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            let size = (value as? UIFont)?.pointSize ?? style.fontSize
            string.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: size), range: range)
        }
    }

    private static func applyStrike(to string: NSMutableAttributedString) {
        string.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue,
                            range: NSRange(location: 0, length: string.length))
        string.addAttribute(.strikethroughColor, value: UIColor.label,
                            range: NSRange(location: 0, length: string.length))
    }

    // MARK: - Entities

    /// Reddit stores the API's HTML-escaped text verbatim, so `&amp;` has to
    /// become `&` before anything else is parsed.
    private static func unescaped(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x200B;", with: "")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
