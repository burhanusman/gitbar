import SwiftUI

/// A view that renders parsed markdown content
struct MarkdownPreviewView: View {
    let content: String

    @State private var blocks: [MarkdownBlock] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.space4) {
                ForEach(blocks) { block in
                    renderBlock(block)
                }
            }
            .padding(Theme.space4)
        }
        .background(Theme.background)
        .onAppear {
            blocks = MarkdownParser.parse(content)
        }
        .onChange(of: content) { newValue in
            blocks = MarkdownParser.parse(newValue)
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)

        case .paragraph(let text):
            renderFormattedText(text)
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(4)

        case .codeBlock(let language, let code):
            renderCodeBlock(language: language, code: code)

        case .inlineCode(let text):
            Text(text)
                .font(.system(size: Theme.fontSM, design: .monospaced))
                .foregroundColor(Theme.syntaxString)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.surface)
                .cornerRadius(4)

        case .blockquote(let text):
            renderBlockquote(text)

        case .unorderedList(let items):
            renderUnorderedList(items)

        case .orderedList(let items):
            renderOrderedList(items)

        case .horizontalRule:
            Divider()
                .background(Theme.border)
                .padding(.vertical, Theme.space2)

        case .link(let text, let url):
            if let linkURL = URL(string: url) {
                Link(text, destination: linkURL)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.accent)
            } else {
                Text(text)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.accent)
            }

        case .image(let alt, _):
            // For now, just show alt text since we can't load arbitrary images
            HStack(spacing: Theme.space2) {
                Image(systemName: "photo")
                    .foregroundColor(Theme.textMuted)
                Text(alt.isEmpty ? "Image" : alt)
                    .font(.system(size: Theme.fontSM))
                    .foregroundColor(Theme.textSecondary)
                    .italic()
            }
            .padding(Theme.space3)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusSmall)

        case .empty:
            EmptyView()
        }
    }

    private func renderHeading(level: Int, text: String) -> some View {
        let fontSize: CGFloat = {
            switch level {
            case 1: return 24
            case 2: return 20
            case 3: return 17
            case 4: return 15
            case 5: return 13
            default: return 13
            }
        }()

        return VStack(alignment: .leading, spacing: Theme.space2) {
            Text(text)
                .font(.system(size: fontSize, weight: level <= 2 ? .bold : .semibold))
                .foregroundColor(Theme.textPrimary)

            if level <= 2 {
                Divider()
                    .background(Theme.border)
            }
        }
        .padding(.top, level == 1 ? Theme.space2 : 0)
    }

    private func renderCodeBlock(language: String?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language badge
            if let lang = language, !lang.isEmpty {
                HStack {
                    Text(lang)
                        .font(.system(size: Theme.fontXS, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, Theme.space2)
                        .padding(.vertical, 4)
                        .background(Theme.surfaceActive)
                        .cornerRadius(4)
                    Spacer()
                }
                .padding(.horizontal, Theme.space3)
                .padding(.top, Theme.space2)
            }

            // Code content with syntax highlighting
            SyntaxHighlightedText(code: code, language: language)
                .padding(Theme.space3)
        }
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func renderBlockquote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.space3) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 3)
                .cornerRadius(1.5)

            renderFormattedText(text)
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textSecondary)
                .italic()
        }
        .padding(.leading, Theme.space2)
    }

    private func renderUnorderedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: Theme.space2) {
                    Text("•")
                        .font(.system(size: Theme.fontBase, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                    renderFormattedText(item)
                        .font(.system(size: Theme.fontBase))
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding(.leading, Theme.space2)
    }

    private func renderOrderedList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: Theme.space2) {
                    Text("\(index + 1).")
                        .font(.system(size: Theme.fontBase, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .frame(width: 24, alignment: .trailing)
                    renderFormattedText(item)
                        .font(.system(size: Theme.fontBase))
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding(.leading, Theme.space2)
    }

    @ViewBuilder
    private func renderFormattedText(_ text: String) -> some View {
        let formats = MarkdownParser.parseInline(text)
        formats.reduce(Text("")) { result, format in
            result + formatToText(format)
        }
    }

    private func formatToText(_ format: InlineFormat) -> Text {
        switch format {
        case .plain(let text):
            return Text(text)

        case .bold(let text):
            return Text(text).bold()

        case .italic(let text):
            return Text(text).italic()

        case .boldItalic(let text):
            return Text(text).bold().italic()

        case .code(let text):
            return Text(text)
                .font(.system(size: Theme.fontSM, design: .monospaced))
                .foregroundColor(Theme.syntaxString)

        case .link(let text, _):
            return Text(text)
                .foregroundColor(Theme.accent)
                .underline()
        }
    }
}

/// A view that displays syntax-highlighted code using Highlightr
struct SyntaxHighlightedText: View {
    let code: String
    let language: String?

    @State private var attributedString: NSAttributedString?

    var body: some View {
        Group {
            if let attributed = attributedString {
                AttributedText(attributedString: attributed)
            } else {
                Text(code)
                    .font(.system(size: 12, weight: .light, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .task {
            // Use lighter font weight for code
            let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .light)
            attributedString = await SyntaxHighlightService.shared.highlight(
                text: code,
                language: language,
                font: font
            )
        }
    }
}

/// A SwiftUI wrapper for displaying NSAttributedString
struct AttributedText: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(labelWithAttributedString: attributedString)
        textField.isEditable = false
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.isBordered = false
        textField.lineBreakMode = .byWordWrapping
        textField.preferredMaxLayoutWidth = 600
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.attributedStringValue = attributedString
    }
}

#Preview {
    MarkdownPreviewView(content: """
    # Markdown Preview

    This is a **bold** and *italic* text example.

    ## Code Example

    ```swift
    func hello() {
        print("Hello, World!")
    }
    ```

    - Item 1
    - Item 2
    - Item 3

    > This is a blockquote

    [Link to Apple](https://apple.com)
    """)
    .frame(width: 600, height: 500)
}
