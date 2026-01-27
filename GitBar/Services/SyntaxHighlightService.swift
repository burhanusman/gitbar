import Foundation
import AppKit
import SwiftUI
import Highlightr
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "SyntaxHighlight")

/// Actor-based service for syntax highlighting using Highlightr
/// Supports 185+ programming languages via highlight.js
actor SyntaxHighlightService {
    static let shared = SyntaxHighlightService()

    private var highlightr: Highlightr?
    private var currentTask: Task<NSAttributedString, Never>?

    /// Maximum file size for syntax highlighting (50KB)
    private let maxFileSize = 50_000

    init() {
        // Initialize Highlightr with a dark theme
        if let hl = Highlightr() {
            // Use a subtle dark theme - "atom-one-dark" or "github-dark"
            hl.setTheme(to: "atom-one-dark")
            self.highlightr = hl
            logger.info("Highlightr initialized with atom-one-dark theme")
        } else {
            logger.error("Failed to initialize Highlightr")
        }
    }

    /// Returns available themes
    func availableThemes() -> [String] {
        return highlightr?.availableThemes() ?? []
    }

    /// Returns available languages
    func availableLanguages() -> [String] {
        return highlightr?.supportedLanguages() ?? []
    }

    /// Sets the highlighting theme
    func setTheme(_ theme: String) {
        highlightr?.setTheme(to: theme)
        logger.info("Theme changed to \(theme)")
    }

    /// Highlights text for a given language with debouncing
    func highlight(text: String, language: String?, font: NSFont) async -> NSAttributedString {
        // Cancel any in-flight highlighting
        currentTask?.cancel()

        logger.debug("Starting highlight for \(language ?? "auto") (\(text.count) chars)")

        let task = Task<NSAttributedString, Never> { [weak highlightr] in
            // Debounce for rapid typing
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            if Task.isCancelled {
                logger.debug("Highlight cancelled")
                return self.plainAttributedString(text, font: font)
            }

            // Skip highlighting for very large files
            if text.count > self.maxFileSize {
                logger.warning("File too large (\(text.count) chars), skipping highlighting")
                return self.plainAttributedString(text, font: font)
            }

            guard let hl = highlightr else {
                logger.warning("Highlightr not available, using plain text")
                return self.plainAttributedString(text, font: font)
            }

            // Map file extension to language name
            let languageName = self.mapLanguage(language)

            // Perform highlighting
            if let highlighted = hl.highlight(text, as: languageName) {
                // Override the font to use our preferred monospace font
                let mutableAttr = NSMutableAttributedString(attributedString: highlighted)
                let fullRange = NSRange(location: 0, length: mutableAttr.length)
                mutableAttr.addAttribute(.font, value: font, range: fullRange)
                logger.debug("Highlight complete for \(languageName ?? "auto")")
                return mutableAttr
            } else {
                logger.warning("Highlighting failed for \(languageName ?? "unknown")")
                return self.plainAttributedString(text, font: font)
            }
        }

        currentTask = task
        return await task.value
    }

    /// Creates a plain attributed string with default styling
    private func plainAttributedString(_ text: String, font: NSFont) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        attributed.addAttributes([
            .font: font,
            .foregroundColor: NSColor(Theme.textPrimary)
        ], range: fullRange)
        return attributed
    }

    /// Maps file extensions to Highlightr language names
    private func mapLanguage(_ ext: String?) -> String? {
        guard let ext = ext?.lowercased() else { return nil }

        // Map common extensions to language names
        let mapping: [String: String] = [
            // JavaScript/TypeScript
            "js": "javascript",
            "jsx": "javascript",
            "ts": "typescript",
            "tsx": "typescript",
            "mjs": "javascript",
            "cjs": "javascript",

            // Web
            "html": "xml",
            "htm": "xml",
            "vue": "xml",
            "svelte": "xml",

            // Python
            "py": "python",
            "pyw": "python",
            "pyi": "python",

            // Ruby
            "rb": "ruby",
            "rake": "ruby",
            "gemspec": "ruby",

            // Shell
            "sh": "bash",
            "bash": "bash",
            "zsh": "bash",
            "fish": "bash",

            // C/C++
            "c": "c",
            "h": "c",
            "cpp": "cpp",
            "cc": "cpp",
            "cxx": "cpp",
            "hpp": "cpp",
            "hxx": "cpp",

            // Other common languages
            "swift": "swift",
            "kt": "kotlin",
            "kts": "kotlin",
            "java": "java",
            "go": "go",
            "rs": "rust",
            "php": "php",
            "cs": "csharp",
            "fs": "fsharp",
            "scala": "scala",
            "r": "r",
            "m": "objectivec",
            "mm": "objectivec",

            // Data/Config formats
            "json": "json",
            "yaml": "yaml",
            "yml": "yaml",
            "toml": "ini",
            "xml": "xml",
            "plist": "xml",

            // Markup
            "md": "markdown",
            "markdown": "markdown",
            "tex": "latex",
            "rst": "plaintext",

            // Scripting
            "lua": "lua",
            "pl": "perl",
            "pm": "perl",
            "tcl": "tcl",
            "awk": "awk",

            // Database
            "sql": "sql",

            // Config
            "dockerfile": "dockerfile",
            "makefile": "makefile",
            "cmake": "cmake",
            "gradle": "gradle",

            // Other
            "diff": "diff",
            "patch": "diff",
            "ini": "ini",
            "conf": "ini",
            "cfg": "ini",
            "gitignore": "plaintext",
            "env": "plaintext",
        ]

        return mapping[ext] ?? ext
    }
}
