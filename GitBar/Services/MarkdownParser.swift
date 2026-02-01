import Foundation
import SwiftUI

/// Represents a parsed markdown block
enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String?, code: String)
    case inlineCode(text: String)
    case blockquote(text: String)
    case unorderedList(items: [String])
    case orderedList(items: [String])
    case horizontalRule
    case link(text: String, url: String)
    case image(alt: String, url: String)
    case empty

    var id: String {
        switch self {
        case .heading(let level, let text):
            return "h\(level)-\(text.hashValue)"
        case .paragraph(let text):
            return "p-\(text.hashValue)"
        case .codeBlock(let lang, let code):
            return "code-\(lang ?? "")-\(code.hashValue)"
        case .inlineCode(let text):
            return "inline-\(text.hashValue)"
        case .blockquote(let text):
            return "quote-\(text.hashValue)"
        case .unorderedList(let items):
            return "ul-\(items.hashValue)"
        case .orderedList(let items):
            return "ol-\(items.hashValue)"
        case .horizontalRule:
            return "hr-\(UUID().uuidString)"
        case .link(let text, let url):
            return "link-\(text)-\(url)"
        case .image(let alt, let url):
            return "img-\(alt)-\(url)"
        case .empty:
            return "empty-\(UUID().uuidString)"
        }
    }
}

/// Represents inline formatting within text
enum InlineFormat {
    case plain(String)
    case bold(String)
    case italic(String)
    case boldItalic(String)
    case code(String)
    case link(text: String, url: String)
}

/// Service for parsing markdown text into blocks
struct MarkdownParser {

    // MARK: - Cached Regex Patterns (compiled once)

    private static let headingRegex = try? NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#)
    private static let horizontalRuleRegex = try? NSRegularExpression(pattern: #"^[-*_]{3,}$"#)
    private static let unorderedListRegex = try? NSRegularExpression(pattern: #"^[-*+]\s+"#)
    private static let unorderedListItemRegex = try? NSRegularExpression(pattern: #"^[-*+]\s+(.+)$"#)
    private static let orderedListRegex = try? NSRegularExpression(pattern: #"^\d+\.\s+"#)
    private static let orderedListItemRegex = try? NSRegularExpression(pattern: #"^\d+\.\s+(.+)$"#)
    private static let imageRegex = try? NSRegularExpression(pattern: #"^!\[([^\]]*)\]\(([^)]+)\)$"#)

    // Inline patterns
    private static let boldItalicRegex = try? NSRegularExpression(pattern: #"^\*\*\*([^*]+)\*\*\*"#)
    private static let boldRegex = try? NSRegularExpression(pattern: #"^\*\*([^*]+)\*\*"#)
    private static let boldUnderscoreRegex = try? NSRegularExpression(pattern: #"^__([^_]+)__"#)
    private static let italicRegex = try? NSRegularExpression(pattern: #"^\*([^*]+)\*"#)
    private static let italicUnderscoreRegex = try? NSRegularExpression(pattern: #"^_([^_]+)_"#)
    private static let inlineCodeRegex = try? NSRegularExpression(pattern: #"^`([^`]+)`"#)
    private static let linkRegex = try? NSRegularExpression(pattern: #"^\[([^\]]+)\]\(([^)]+)\)"#)

    // MARK: - Regex Helpers

    private static func matches(_ regex: NSRegularExpression?, in text: String) -> Bool {
        guard let regex = regex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    private static func captureGroups(_ regex: NSRegularExpression?, in text: String) -> [String]? {
        guard let regex = regex else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            if let range = Range(match.range(at: i), in: text) {
                groups.append(String(text[range]))
            } else {
                groups.append("")
            }
        }
        return groups
    }

    /// Parses markdown text into an array of blocks
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1

                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }

                let code = codeLines.joined(separator: "\n")
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: code))
                continue
            }

            // Heading: ^(#{1,6})\s+(.+)$
            if let groups = captureGroups(headingRegex, in: trimmed), groups.count >= 3 {
                let level = groups[1].count
                let text = groups[2]
                blocks.append(.heading(level: level, text: text))
                index += 1
                continue
            }

            // Horizontal rule: ^[-*_]{3,}$
            if matches(horizontalRuleRegex, in: trimmed) {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let quoteLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if quoteLine.hasPrefix(">") {
                        let content = String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces)
                        quoteLines.append(content)
                        index += 1
                    } else if quoteLine.isEmpty {
                        index += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(text: quoteLines.joined(separator: "\n")))
                continue
            }

            // Unordered list: ^[-*+]\s+
            if matches(unorderedListRegex, in: trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let listLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if let groups = captureGroups(unorderedListItemRegex, in: listLine), groups.count >= 2 {
                        items.append(groups[1])
                        index += 1
                    } else if listLine.isEmpty {
                        index += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.unorderedList(items: items))
                continue
            }

            // Ordered list: ^\d+\.\s+
            if matches(orderedListRegex, in: trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let listLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if let groups = captureGroups(orderedListItemRegex, in: listLine), groups.count >= 2 {
                        items.append(groups[1])
                        index += 1
                    } else if listLine.isEmpty {
                        index += 1
                        break
                    } else {
                        break
                    }
                }
                blocks.append(.orderedList(items: items))
                continue
            }

            // Image (standalone): ^!\[([^\]]*)\]\(([^)]+)\)$
            if let groups = captureGroups(imageRegex, in: trimmed), groups.count >= 3 {
                blocks.append(.image(alt: groups[1], url: groups[2]))
                index += 1
                continue
            }

            // Paragraph (collect consecutive non-empty lines)
            var paragraphLines: [String] = []
            while index < lines.count {
                let pLine = lines[index]
                let pTrimmed = pLine.trimmingCharacters(in: .whitespaces)

                // Stop at block-level elements or empty lines
                if pTrimmed.isEmpty ||
                   pTrimmed.hasPrefix("#") ||
                   pTrimmed.hasPrefix("```") ||
                   pTrimmed.hasPrefix(">") ||
                   matches(unorderedListRegex, in: pTrimmed) ||
                   matches(orderedListRegex, in: pTrimmed) ||
                   matches(horizontalRuleRegex, in: pTrimmed) {
                    break
                }

                paragraphLines.append(pTrimmed)
                index += 1
            }

            if !paragraphLines.isEmpty {
                blocks.append(.paragraph(text: paragraphLines.joined(separator: " ")))
            }
        }

        return blocks
    }

    /// Parses inline formatting in text (optimized with cached regexes)
    static func parseInline(_ text: String) -> [InlineFormat] {
        // For very long text, skip inline parsing to avoid performance issues
        guard text.count < 5000 else {
            return [.plain(text)]
        }

        var formats: [InlineFormat] = []
        var remaining = text

        while !remaining.isEmpty {
            // Bold + Italic (***text*** or ___text___)
            if let groups = captureGroups(boldItalicRegex, in: remaining), groups.count >= 2 {
                formats.append(.boldItalic(groups[1]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            // Bold (**text** or __text__)
            if let groups = captureGroups(boldRegex, in: remaining), groups.count >= 2 {
                formats.append(.bold(groups[1]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            if let groups = captureGroups(boldUnderscoreRegex, in: remaining), groups.count >= 2 {
                formats.append(.bold(groups[1]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            // Italic (*text* or _text_)
            if let groups = captureGroups(italicRegex, in: remaining), groups.count >= 2 {
                formats.append(.italic(groups[1]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            if let groups = captureGroups(italicUnderscoreRegex, in: remaining), groups.count >= 2 {
                formats.append(.italic(groups[1]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            // Inline code (`code`)
            if let groups = captureGroups(inlineCodeRegex, in: remaining), groups.count >= 2 {
                formats.append(.code(groups[1]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            // Link [text](url)
            if let groups = captureGroups(linkRegex, in: remaining), groups.count >= 3 {
                formats.append(.link(text: groups[1], url: groups[2]))
                remaining = String(remaining.dropFirst(groups[0].count))
                continue
            }

            // Plain text (up to next special character)
            if let nextSpecial = remaining.firstIndex(where: { "*_`[".contains($0) }) {
                if nextSpecial == remaining.startIndex {
                    // Special char didn't match a pattern, treat as plain
                    formats.append(.plain(String(remaining.first!)))
                    remaining = String(remaining.dropFirst())
                } else {
                    formats.append(.plain(String(remaining[..<nextSpecial])))
                    remaining = String(remaining[nextSpecial...])
                }
            } else {
                formats.append(.plain(remaining))
                remaining = ""
            }
        }

        return formats
    }
}
