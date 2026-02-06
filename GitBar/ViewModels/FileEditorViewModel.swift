import Foundation
import SwiftUI
import AppKit
import Combine
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "FileEditor")

/// Notification posted when a file is saved
extension Notification.Name {
    static let fileDidSave = Notification.Name("fileDidSave")
}

/// Editor display mode
enum EditorMode: String, CaseIterable {
    case edit = "Edit"
    case preview = "Preview"
}

/// ViewModel for managing the file editor state
@MainActor
class FileEditorViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var originalContent: String = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: Error?
    @Published var saveSuccess = false
    @Published var filePath: String = ""
    @Published var fileName: String = ""
    @Published var cursorPosition: CursorPosition = CursorPosition(line: 1, column: 1)

    // Syntax highlighting & preview
    @Published var highlightedContent: NSAttributedString?
    @Published var editorMode: EditorMode = .edit
    @Published var isHighlighting = false

    private let fileService = FileService()
    private var repoPath: String?
    private var highlightTask: Task<Void, Never>?
    private var highlightTimer: Timer?

    /// Maximum file size (in characters) to apply syntax highlighting
    /// Files larger than this will use plain text to avoid performance issues
    private let maxHighlightSize = 15_000  // ~15KB

    /// Whether there are unsaved changes
    var hasUnsavedChanges: Bool {
        content != originalContent
    }

    /// Number of lines in the content
    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    /// Loads a file for editing
    func loadFile(at path: String, repoPath: String? = nil) {
        logger.info("✏️ loadFile START: \(path)")
        self.filePath = path
        self.fileName = (path as NSString).lastPathComponent
        self.repoPath = repoPath
        self.isLoading = true
        self.error = nil

        Task {
            do {
                logger.debug("✏️ reading file...")
                let fileContent = try await fileService.readFile(at: path)
                logger.debug("✏️ file loaded: \(fileContent.count) chars")
                self.content = fileContent
                self.originalContent = fileContent
                self.isLoading = false
                // Trigger initial syntax highlighting
                logger.debug("✏️ triggering highlight...")
                self.highlightContent()
                logger.info("✏️ loadFile DONE")
            } catch {
                logger.error("✏️ loadFile ERROR: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Saves the current content to the file
    func save() async throws {
        guard hasUnsavedChanges else { return }

        isSaving = true
        error = nil
        saveSuccess = false

        do {
            try await fileService.writeFile(content: content, to: filePath)
            self.originalContent = content
            self.saveSuccess = true

            // Post notification for status refresh
            NotificationCenter.default.post(name: .fileDidSave, object: filePath)

            // Reset success after delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.saveSuccess = false
            }
        } catch {
            self.error = error
            throw error
        }

        isSaving = false
    }

    /// Reverts to the original content
    func revert() {
        content = originalContent
        error = nil
    }

    /// Updates cursor position based on text selection
    func updateCursorPosition(from text: String, selectedRange: NSRange) {
        let lines = text.prefix(selectedRange.location).components(separatedBy: .newlines)
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1
        cursorPosition = CursorPosition(line: line, column: column)
    }

    /// Returns the file extension for syntax highlighting hints
    var fileExtension: String? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    /// Returns a descriptive encoding string
    var encodingDescription: String {
        "UTF-8"
    }

    /// Whether the current file is a markdown file
    var isMarkdownFile: Bool {
        guard let ext = fileExtension else { return false }
        return ext == "md" || ext == "markdown"
    }

    /// Schedules syntax highlighting with debounce to avoid freezing during rapid typing
    /// Call this instead of highlightContent() when the user is actively editing
    func scheduleHighlighting() {
        // Cancel any pending timer
        highlightTimer?.invalidate()

        // Schedule highlighting 500ms after the last keystroke
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.highlightContent()
            }
        }
    }

    /// Triggers syntax highlighting for the current content
    /// For large files, highlighting is skipped to maintain responsiveness
    func highlightContent() {
        // Cancel any in-flight highlighting
        highlightTask?.cancel()
        highlightTimer?.invalidate()

        let text = content
        let language = fileExtension
        logger.debug("✏️ highlightContent: \(text.count) chars, lang=\(language ?? "nil")")

        // Skip highlighting for large files to maintain responsiveness
        guard text.count < maxHighlightSize else {
            logger.debug("✏️ file too large (\(text.count) chars), skipping highlighting")
            highlightedContent = nil
            isHighlighting = false
            return
        }

        highlightTask = Task {
            isHighlighting = true

            let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .light)
            logger.debug("✏️ calling SyntaxHighlightService...")
            let highlighted = await SyntaxHighlightService.shared.highlight(
                text: text,
                language: language,
                font: font
            )

            if !Task.isCancelled {
                logger.debug("✏️ highlight complete, updating UI")
                self.highlightedContent = highlighted
                self.isHighlighting = false
            } else {
                logger.debug("✏️ highlight cancelled")
            }
        }
    }

    /// Toggles between edit and preview mode (for markdown files)
    func togglePreviewMode() {
        editorMode = editorMode == .edit ? .preview : .edit
    }
}

/// Represents cursor position in the editor
struct CursorPosition: Equatable {
    let line: Int
    let column: Int

    var description: String {
        "Ln \(line), Col \(column)"
    }
}
