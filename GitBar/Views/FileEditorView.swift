import SwiftUI
import AppKit

/// A sheet view for editing a file
struct FileEditorView: View {
    let filePath: String
    let repoPath: String

    @StateObject private var viewModel = FileEditorViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showUnsavedChangesAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Theme.border)

            // Content
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error, viewModel.content.isEmpty {
                errorView(error: error)
            } else {
                editorView
            }

            Divider()
                .background(Theme.border)

            // Footer
            footerView
        }
        .frame(width: 700, height: 500)
        .background(Theme.background)
        .onAppear {
            viewModel.loadFile(at: filePath, repoPath: repoPath)
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task {
                    try? await viewModel.save()
                    dismiss()
                }
            }
        } message: {
            Text("You have unsaved changes. Do you want to save them before closing?")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Theme.space3) {
            // File icon and path
            HStack(spacing: Theme.space2) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                Text(viewModel.fileName)
                    .font(.system(size: Theme.fontBase, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                // Unsaved indicator
                if viewModel.hasUnsavedChanges {
                    Circle()
                        .fill(Theme.warning)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: Theme.space2) {
                // Save button
                Button(action: {
                    Task {
                        try? await viewModel.save()
                    }
                }) {
                    HStack(spacing: 4) {
                        if viewModel.isSaving {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else if viewModel.saveSuccess {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 11, weight: .medium))
                        }
                        Text("Save")
                            .font(.system(size: Theme.fontSM, weight: .medium))
                    }
                    .foregroundColor(viewModel.hasUnsavedChanges ? .white : Theme.textMuted)
                    .padding(.horizontal, Theme.space3)
                    .padding(.vertical, 6)
                    .background(viewModel.hasUnsavedChanges ? Theme.accent : Theme.surface)
                    .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                .keyboardShortcut("s", modifiers: .command)
                .help("Save (Cmd+S)")
                .pointingHandCursor()

                // Revert button
                Button(action: {
                    viewModel.revert()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .medium))
                        Text("Revert")
                            .font(.system(size: Theme.fontSM, weight: .medium))
                    }
                    .foregroundColor(viewModel.hasUnsavedChanges ? Theme.textSecondary : Theme.textMuted)
                    .padding(.horizontal, Theme.space3)
                    .padding(.vertical, 6)
                    .background(Theme.surface)
                    .cornerRadius(Theme.radiusSmall)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasUnsavedChanges)
                .help("Revert changes")
                .pointingHandCursor()
            }

            // Close button
            Button(action: {
                if viewModel.hasUnsavedChanges {
                    showUnsavedChangesAlert = true
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 20, height: 20)
                    .background(Theme.surface)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close")
            .pointingHandCursor()
        }
        .padding(.horizontal, Theme.space4)
        .padding(.vertical, Theme.space3)
        .background(Theme.surfaceElevated)
    }

    // MARK: - Editor

    private var editorView: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line numbers gutter
            lineNumbersGutter

            Divider()
                .background(Theme.border)

            // Text editor
            textEditorView
        }
        .background(Theme.background)
    }

    private var lineNumbersGutter: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(1...max(viewModel.lineCount, 1), id: \.self) { lineNumber in
                    Text("\(lineNumber)")
                        .font(.system(size: Theme.fontSM, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                        .padding(.trailing, Theme.space2)
                        .frame(height: 20)
                }
            }
            .padding(.vertical, Theme.space3)
        }
        .frame(width: 50)
        .background(Theme.surfaceElevated)
    }

    private var textEditorView: some View {
        CodeTextEditor(text: $viewModel.content)
            .background(Theme.background)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: Theme.space4) {
            // Unsaved indicator
            if viewModel.hasUnsavedChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.warning)
                        .frame(width: 6, height: 6)
                    Text("Unsaved changes")
                        .font(.system(size: Theme.fontXS))
                        .foregroundColor(Theme.textMuted)
                }
            } else if viewModel.saveSuccess {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.success)
                    Text("Saved")
                        .font(.system(size: Theme.fontXS))
                        .foregroundColor(Theme.success)
                }
            }

            // Error message
            if let error = viewModel.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.error)
                    Text(error.localizedDescription)
                        .font(.system(size: Theme.fontXS))
                        .foregroundColor(Theme.error)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Line count
            Text("\(viewModel.lineCount) lines")
                .font(.system(size: Theme.fontXS, design: .monospaced))
                .foregroundColor(Theme.textMuted)

            // Encoding
            Text(viewModel.encodingDescription)
                .font(.system(size: Theme.fontXS))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, Theme.space4)
        .padding(.vertical, Theme.space2)
        .background(Theme.surfaceElevated)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Theme.space4) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading file...")
                .font(.system(size: Theme.fontBase))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: Theme.space4) {
            ZStack {
                Circle()
                    .fill(Theme.errorMuted)
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.error)
            }

            VStack(spacing: Theme.space2) {
                Text("Cannot open file")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(error.localizedDescription)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.space8)
            }

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Code Text Editor (NSTextView wrapper)

struct CodeTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Configure text view
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        // Font
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

        // Text color
        textView.textColor = NSColor(Theme.textPrimary)

        // Insets
        textView.textContainerInset = NSSize(width: 12, height: 12)

        // Container setup
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width, .height]

        // Set initial text
        textView.string = text

        // Set delegate
        textView.delegate = context.coordinator

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text has changed from external source
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Preserve cursor position if possible
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeTextEditor

        init(_ parent: CodeTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

#Preview {
    FileEditorView(filePath: "/Users/test/file.swift", repoPath: "/Users/test")
}
