import Foundation
import SwiftUI
import Combine

/// Notification posted when a file is saved
extension Notification.Name {
    static let fileDidSave = Notification.Name("fileDidSave")
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

    private let fileService = FileService()
    private var repoPath: String?

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
        self.filePath = path
        self.fileName = (path as NSString).lastPathComponent
        self.repoPath = repoPath
        self.isLoading = true
        self.error = nil

        Task {
            do {
                let fileContent = try await fileService.readFile(at: path)
                self.content = fileContent
                self.originalContent = fileContent
                self.isLoading = false
            } catch {
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
}

/// Represents cursor position in the editor
struct CursorPosition: Equatable {
    let line: Int
    let column: Int

    var description: String {
        "Ln \(line), Col \(column)"
    }
}
