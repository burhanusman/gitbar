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
    let onSave: (String, String, TicketStatus, [TicketImage]) async throws -> Void
    let onSaveImage: ((NSImage, Int) async throws -> TicketImage)?
    let onLoadImage: ((TicketImage, Int) async -> NSImage?)?
    let onDeleteImage: ((TicketImage, Int) async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var status: TicketStatus = .open
    @State private var pendingImages: [PendingImage] = []
    @State private var imagesToDelete: [TicketImage] = []
    @State private var isSaving = false
    @State private var error: Error?
    @State private var isLoadingImages = false

    private var isEditing: Bool {
        existingTicket != nil
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        existingTicket: Ticket? = nil,
        onSave: @escaping (String, String, TicketStatus, [TicketImage]) async throws -> Void,
        onSaveImage: ((NSImage, Int) async throws -> TicketImage)? = nil,
        onLoadImage: ((TicketImage, Int) async -> NSImage?)? = nil,
        onDeleteImage: ((TicketImage, Int) async throws -> Void)? = nil
    ) {
        self.existingTicket = existingTicket
        self.onSave = onSave
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
                loadExistingImages()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Check for pasteable images when app becomes active
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

                    try await onSave(trimmedTitle, trimmedDescription, status, finalImages)
                } else {
                    // New ticket - images will be added after creation
                    // For now, just create without images
                    try await onSave(trimmedTitle, trimmedDescription, status, [])
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
    TicketEditorView { _, _, _, _ in }
}

#Preview("Edit") {
    TicketEditorView(
        existingTicket: Ticket.create(id: 1, title: "Fix login bug", description: "The form fails silently"),
        onSave: { _, _, _, _ in }
    )
}
