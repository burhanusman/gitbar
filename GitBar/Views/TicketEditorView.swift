import SwiftUI
import AppKit

/// Represents a pending image (either new or existing)
struct PendingImage: Identifiable {
    let id: String
    let image: NSImage
    let ticketImage: TicketImage?  // nil if new, has value if existing

    var isNew: Bool { ticketImage == nil }
}

/// Sheet view for creating or editing a ticket
struct TicketEditorView: View {
    let existingTicket: Ticket?
    let availableTickets: [Ticket]
    let onSave: (String, String, TicketStatus, [TicketImage], [Int]) async throws -> Void
    let onCreateWithImages: ((String, String, TicketStatus, [NSImage], [Int]) async throws -> Void)?
    let onSaveImage: ((NSImage, Int) async throws -> TicketImage)?
    let onLoadImage: ((TicketImage, Int) async -> NSImage?)?
    let onDeleteImage: ((TicketImage, Int) async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var status: TicketStatus = .open
    @State private var selectedDependencyIds: Set<Int> = []
    @State private var pendingImages: [PendingImage] = []
    @State private var imagesToDelete: [TicketImage] = []
    @State private var isSaving = false
    @State private var error: Error?
    @State private var isLoadingImages = false

    // Voice recording state
    @StateObject private var audioService = AudioRecordingService()
    @State private var isTranscribing = false

    private var isEditing: Bool {
        existingTicket != nil
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        existingTicket: Ticket? = nil,
        availableTickets: [Ticket] = [],
        onSave: @escaping (String, String, TicketStatus, [TicketImage], [Int]) async throws -> Void,
        onCreateWithImages: ((String, String, TicketStatus, [NSImage], [Int]) async throws -> Void)? = nil,
        onSaveImage: ((NSImage, Int) async throws -> TicketImage)? = nil,
        onLoadImage: ((TicketImage, Int) async -> NSImage?)? = nil,
        onDeleteImage: ((TicketImage, Int) async throws -> Void)? = nil
    ) {
        self.existingTicket = existingTicket
        self.availableTickets = availableTickets
        self.onSave = onSave
        self.onCreateWithImages = onCreateWithImages
        self.onSaveImage = onSaveImage
        self.onLoadImage = onLoadImage
        self.onDeleteImage = onDeleteImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Theme.border)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space4) {
                    // Title field
                    VStack(alignment: .leading, spacing: Theme.space2) {
                        Text("Title")
                            .font(.system(size: Theme.fontSM, weight: .medium))
                            .foregroundColor(Theme.textSecondary)

                        TextField("What needs to be done?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: Theme.fontBase))
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.space3)
                            .background(Theme.surface)
                            .cornerRadius(Theme.radiusSmall)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                    }

                    // Description field
                    VStack(alignment: .leading, spacing: Theme.space2) {
                        Text("Description")
                            .font(.system(size: Theme.fontSM, weight: .medium))
                            .foregroundColor(Theme.textSecondary)

                        TextEditor(text: $description)
                            .font(.system(size: Theme.fontBase))
                            .foregroundColor(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.space3)
                            .background(Theme.surface)
                            .cornerRadius(Theme.radiusSmall)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                            .frame(minHeight: 100, maxHeight: 200)
                    }

                    // Status picker (only show when editing)
                    if isEditing {
                        VStack(alignment: .leading, spacing: Theme.space2) {
                            Text("Status")
                                .font(.system(size: Theme.fontSM, weight: .medium))
                                .foregroundColor(Theme.textSecondary)

                            HStack(spacing: Theme.space2) {
                                ForEach(TicketStatus.allCases, id: \.self) { statusOption in
                                    StatusPill(
                                        status: statusOption,
                                        isSelected: status == statusOption,
                                        action: { status = statusOption }
                                    )
                                }
                            }
                        }
                    }

                    dependencySection

                    // Images section
                    VStack(alignment: .leading, spacing: Theme.space2) {
                        HStack {
                            Text("Images")
                                .font(.system(size: Theme.fontSM, weight: .medium))
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Button(action: addImageFromFile) {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 10))
                                    Text("Add")
                                        .font(.system(size: Theme.fontXS, weight: .medium))
                                }
                                .foregroundColor(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Add image from file")
                            .pointingHandCursor()

                            Button(action: pasteImage) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 10))
                                    Text("Paste")
                                        .font(.system(size: Theme.fontXS, weight: .medium))
                                }
                                .foregroundColor(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Paste image from clipboard (⌘V)")
                            .pointingHandCursor()
                        }

                        // Voice input section
                        VStack(alignment: .leading, spacing: Theme.space2) {
                            HStack {
                                Text("Voice Input")
                                    .font(.system(size: Theme.fontSM, weight: .medium))
                                    .foregroundColor(Theme.textSecondary)

                                Spacer()

                                if isTranscribing {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                        Text("Transcribing...")
                                            .font(.system(size: Theme.fontXS))
                                            .foregroundColor(Theme.textMuted)
                                    }
                                } else if audioService.isRecording {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Theme.error)
                                            .frame(width: 8, height: 8)
                                        Text(audioService.formattedDuration)
                                            .font(.system(size: Theme.fontXS, weight: .medium).monospacedDigit())
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }

                            Button(action: toggleVoiceRecording) {
                                HStack(spacing: 8) {
                                    Image(systemName: audioService.isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 14, weight: .medium))
                                    Text(audioService.isRecording ? "Stop Recording" : "Record Voice Note")
                                        .font(.system(size: Theme.fontSM, weight: .medium))
                                }
                                .foregroundColor(audioService.isRecording ? Theme.error : Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(audioService.isRecording ? Theme.error.opacity(0.1) : Theme.accentMuted)
                                .cornerRadius(Theme.radiusSmall)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                        .stroke(audioService.isRecording ? Theme.error.opacity(0.3) : Theme.accent.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isTranscribing)
                            .help(audioService.isRecording ? "Stop recording and transcribe" : "Record voice to create ticket content")
                            .pointingHandCursor()

                            Text("Voice recording will be transcribed to fill title and description")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textMuted)
                        }

                        if pendingImages.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 20))
                                        .foregroundColor(Theme.textMuted)
                                    Text("No images attached")
                                        .font(.system(size: Theme.fontXS))
                                        .foregroundColor(Theme.textMuted)
                                    Text("Drag & drop, paste, or click Add")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.textMuted.opacity(0.7))
                                }
                                .padding(.vertical, Theme.space4)
                                Spacer()
                            }
                            .background(Theme.surface)
                            .cornerRadius(Theme.radiusSmall)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                                    .stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.space2) {
                                    ForEach(pendingImages) { pending in
                                        ImageThumbnailView(
                                            image: pending.image,
                                            onRemove: { removeImage(pending) }
                                        )
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                        handleDrop(providers: providers)
                        return true
                    }

                    // Error message
                    if let error = error {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.error)
                            Text(error.localizedDescription)
                                .font(.system(size: Theme.fontXS))
                                .foregroundColor(Theme.error)
                        }
                    }
                }
                .padding(Theme.space4)
            }

            Divider()
                .background(Theme.border)

            // Footer
            footerView
        }
        .frame(width: 500, height: 500)
        .background(Theme.background)
        .onAppear {
            if let ticket = existingTicket {
                title = ticket.title
                description = ticket.description
                status = ticket.status
                selectedDependencyIds = Set(ticket.dependencies)
                loadExistingImages()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Check for pasteable images when app becomes active
        }
    }

    // MARK: - Dependencies

    private var dependencySection: some View {
        VStack(alignment: .leading, spacing: Theme.space2) {
            HStack {
                Text("Dependencies")
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                if !selectableDependencyTickets.isEmpty {
                    Menu {
                        ForEach(selectableDependencyTickets) { ticket in
                            Button(action: { selectedDependencyIds.insert(ticket.id) }) {
                                Label(
                                    "#\(ticket.id) \(ticket.title)",
                                    systemImage: ticket.status.icon
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Add")
                                .font(.system(size: Theme.fontXS, weight: .medium))
                        }
                        .foregroundColor(Theme.accent)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .pointingHandCursor()
                }
            }

            if selectedDependencyIds.isEmpty {
                Text("No dependencies — this ticket can start immediately")
                    .font(.system(size: Theme.fontXS))
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Theme.space2)
            } else {
                VStack(spacing: 0) {
                    ForEach(selectedDependencyIds.sorted(), id: \.self) { dependencyId in
                        dependencyRow(for: dependencyId)

                        if dependencyId != selectedDependencyIds.sorted().last {
                            Divider()
                                .overlay(Theme.borderSubtle)
                        }
                    }
                }
                .background(Theme.surface)
                .cornerRadius(Theme.radiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }

            Text("A dependency is ready when its ticket is marked Done")
                .font(.system(size: 9))
                .foregroundColor(Theme.textMuted)
        }
    }

    private var selectableDependencyTickets: [Ticket] {
        availableTickets
            .filter { !selectedDependencyIds.contains($0.id) && $0.id != existingTicket?.id }
            .sorted { $0.id < $1.id }
    }

    @ViewBuilder
    private func dependencyRow(for dependencyId: Int) -> some View {
        let ticket = availableTickets.first { $0.id == dependencyId }
        let color = dependencyColor(for: ticket)

        HStack(spacing: Theme.space2) {
            Image(systemName: ticket?.status.icon ?? "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 16)

            Text("#\(dependencyId)")
                .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                .foregroundColor(color)

            Text(ticket?.title ?? "Ticket not found")
                .font(.system(size: Theme.fontSM))
                .foregroundColor(ticket == nil ? Theme.error : Theme.textSecondary)
                .lineLimit(1)

            Spacer()

            Button(action: { selectedDependencyIds.remove(dependencyId) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove dependency")
            .pointingHandCursor()
        }
        .padding(.horizontal, Theme.space3)
        .padding(.vertical, Theme.space2)
    }

    private func dependencyColor(for ticket: Ticket?) -> Color {
        guard let ticket else { return Theme.error }

        switch ticket.status {
        case .open:
            return Theme.accent
        case .inProgress:
            return Theme.warning
        case .done:
            return Theme.success
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Theme.space3) {
            Image(systemName: isEditing ? "pencil" : "plus.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.accent)

            Text(isEditing ? "Edit Ticket" : "New Ticket")
                .font(.system(size: Theme.fontBase, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button(action: { dismiss() }) {
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

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: Theme.space3) {
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, Theme.space3)
            .padding(.vertical, 6)
            .background(Theme.surface)
            .cornerRadius(Theme.radiusSmall)
            .pointingHandCursor()

            Button(action: saveTicket) {
                HStack(spacing: 4) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: isEditing ? "checkmark" : "plus")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Text(isEditing ? "Save" : "Create")
                        .font(.system(size: Theme.fontSM, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.space3)
                .padding(.vertical, 6)
                .background(isValid ? Theme.accent : Theme.accent.opacity(0.5))
                .cornerRadius(Theme.radiusSmall)
            }
            .buttonStyle(.plain)
            .disabled(!isValid || isSaving)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Save (Cmd+Return)")
            .pointingHandCursor()
        }
        .padding(.horizontal, Theme.space4)
        .padding(.vertical, Theme.space3)
        .background(Theme.surfaceElevated)
    }

    // MARK: - Actions

    private func saveTicket() {
        guard isValid else { return }
        isSaving = true
        error = nil

        Task {
            do {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
                let dependencies = selectedDependencyIds.sorted()

                // For existing tickets, handle images
                if let ticketId = existingTicket?.id {
                    // Save new images
                    var finalImages: [TicketImage] = []
                    for pending in pendingImages {
                        if let existingImage = pending.ticketImage {
                            // Keep existing image reference
                            finalImages.append(existingImage)
                        } else if let onSaveImage = onSaveImage {
                            // Save new image
                            let savedImage = try await onSaveImage(pending.image, ticketId)
                            finalImages.append(savedImage)
                        }
                    }

                    // Delete removed images
                    for imageToDelete in imagesToDelete {
                        try await onDeleteImage?(imageToDelete, ticketId)
                    }

                    try await onSave(trimmedTitle, trimmedDescription, status, finalImages, dependencies)
                } else if let onCreateWithImages = onCreateWithImages {
                    let images = pendingImages.map(\.image)
                    try await onCreateWithImages(trimmedTitle, trimmedDescription, status, images, dependencies)
                } else {
                    try await onSave(trimmedTitle, trimmedDescription, status, [], dependencies)
                }
                dismiss()
            } catch {
                self.error = error
                isSaving = false
            }
        }
    }

    // MARK: - Image Handling

    private func loadExistingImages() {
        guard let ticket = existingTicket, !ticket.images.isEmpty else { return }
        isLoadingImages = true

        Task {
            var loaded: [PendingImage] = []
            for ticketImage in ticket.images {
                if let image = await onLoadImage?(ticketImage, ticket.id) {
                    loaded.append(PendingImage(
                        id: ticketImage.id,
                        image: image,
                        ticketImage: ticketImage
                    ))
                }
            }
            await MainActor.run {
                pendingImages = loaded
                isLoadingImages = false
            }
        }
    }

    private func addImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.title = "Select Images"

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    let pending = PendingImage(
                        id: UUID().uuidString,
                        image: image,
                        ticketImage: nil
                    )
                    pendingImages.append(pending)
                }
            }
        }
    }

    private func pasteImage() {
        let pasteboard = NSPasteboard.general

        // Try to get image directly
        if let image = NSImage(pasteboard: pasteboard) {
            let pending = PendingImage(
                id: UUID().uuidString,
                image: image,
                ticketImage: nil
            )
            pendingImages.append(pending)
            return
        }

        // Try to get image from file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let image = NSImage(contentsOf: url) {
                    let pending = PendingImage(
                        id: UUID().uuidString,
                        image: image,
                        ticketImage: nil
                    )
                    pendingImages.append(pending)
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Try to load as image
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let image = image as? NSImage {
                        DispatchQueue.main.async {
                            let pending = PendingImage(
                                id: UUID().uuidString,
                                image: image,
                                ticketImage: nil
                            )
                            pendingImages.append(pending)
                        }
                    }
                }
            }
            // Try to load as file URL
            else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                    if let data = data as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            let pending = PendingImage(
                                id: UUID().uuidString,
                                image: image,
                                ticketImage: nil
                            )
                            pendingImages.append(pending)
                        }
                    }
                }
            }
        }
    }

    private func removeImage(_ pending: PendingImage) {
        pendingImages.removeAll { $0.id == pending.id }
        // Track existing images for deletion
        if let ticketImage = pending.ticketImage {
            imagesToDelete.append(ticketImage)
        }
    }

    // MARK: - Voice Recording

    private func toggleVoiceRecording() {
        if audioService.isRecording {
            stopRecordingAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            // Request permission if needed
            let hasPermission = await audioService.requestMicrophonePermission()
            guard hasPermission else {
                error = AudioRecordingError.microphonePermissionDenied
                return
            }

            do {
                try audioService.startRecording()
            } catch {
                self.error = error
            }
        }
    }

    private func stopRecordingAndTranscribe() {
        guard let audioData = audioService.stopRecording() else {
            error = AudioRecordingError.noRecordingInProgress
            return
        }

        isTranscribing = true
        error = nil

        Task {
            do {
                let transcription = try await OpenAIService.shared.transcribe(audioData: audioData)
                parseTranscription(transcription)
            } catch {
                self.error = error
            }
            isTranscribing = false
        }
    }

    private func parseTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to split into title and description
        // First sentence becomes title, rest becomes description
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        if let firstSentenceEnd = trimmed.rangeOfCharacter(from: sentenceEnders) {
            let potentialTitle = String(trimmed[..<firstSentenceEnd.upperBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let potentialDescription = String(trimmed[firstSentenceEnd.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Only split if title is reasonable length (under 100 chars)
            if potentialTitle.count <= 100 && !potentialDescription.isEmpty {
                title = potentialTitle
                description = potentialDescription
                return
            }
        }

        // If no good split found, put everything in title if short, else in description
        if trimmed.count <= 100 {
            title = trimmed
        } else {
            // Use first 100 chars as title, rest as description
            let titleEnd = trimmed.index(trimmed.startIndex, offsetBy: min(100, trimmed.count))
            title = String(trimmed[..<titleEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            description = String(trimmed[titleEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

// MARK: - Image Thumbnail View

private struct ImageThumbnailView: View {
    let image: NSImage
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 60)
                .clipped()
                .cornerRadius(Theme.radiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .stroke(Theme.border, lineWidth: 1)
                )

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .pointingHandCursor()
            }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Status Pill

private struct StatusPill: View {
    let status: TicketStatus
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var statusColor: Color {
        switch status {
        case .open:
            return Theme.accent
        case .inProgress:
            return Theme.warning
        case .done:
            return Theme.success
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(status.displayName)
                    .font(.system(size: Theme.fontXS, weight: .medium))
            }
            .foregroundColor(isSelected ? statusColor : Theme.textMuted)
            .padding(.horizontal, Theme.space3)
            .padding(.vertical, 6)
            .background(isSelected ? statusColor.opacity(0.15) : Theme.surface)
            .cornerRadius(Theme.radiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(isSelected ? statusColor.opacity(0.3) : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointingHandCursor()
    }
}

#Preview("Create") {
    TicketEditorView { _, _, _, _, _ in }
}

#Preview("Edit") {
    TicketEditorView(
        existingTicket: Ticket.create(id: 1, title: "Fix login bug", description: "The form fails silently"),
        onSave: { _, _, _, _, _ in }
    )
}
