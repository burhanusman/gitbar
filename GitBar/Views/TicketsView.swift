import SwiftUI

/// View for browsing and managing tickets in a repository
struct TicketsView: View {
    let project: Project
    var worktreePath: String? = nil
    @StateObject private var viewModel = TicketsBrowserViewModel()

    private var effectivePath: String {
        worktreePath ?? project.path
    }

    @State private var showingCreateSheet = false
    @State private var selectedTicketForEditing: Ticket?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
                .padding(.horizontal, Theme.space6)
                .padding(.vertical, Theme.space4)
                .background(Theme.surfaceElevated)

            Divider()
                .background(Theme.border)

            // Filter bar
            filterBar
                .padding(.horizontal, Theme.space4)
                .padding(.vertical, Theme.space2)
                .background(Theme.surfaceElevated.opacity(0.5))

            Divider()
                .background(Theme.border)

            // Content
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.filteredTickets.isEmpty {
                emptyStateView
            } else {
                ticketListView
            }
        }
        .background(Theme.background)
        .onAppear {
            viewModel.loadTickets(at: effectivePath)
        }
        .onChange(of: project.path) { _ in
            viewModel.loadTickets(at: effectivePath)
        }
        .onChange(of: worktreePath) { _ in
            viewModel.loadTickets(at: effectivePath)
        }
        .sheet(isPresented: $showingCreateSheet) {
            TicketEditorView(
                onSave: { title, description, status, images in
                    try await viewModel.createTicket(title: title, description: description, status: status, images: images)
                },
                onSaveImage: { image, ticketId in
                    try await viewModel.saveImage(image, for: ticketId)
                }
            )
        }
        .sheet(item: $selectedTicketForEditing) { ticket in
            TicketEditorView(
                existingTicket: ticket,
                onSave: { title, description, status, images in
                    let updated = ticket.updated(title: title, description: description, status: status, images: images)
                    try await viewModel.updateTicket(updated)
                },
                onSaveImage: { image, ticketId in
                    try await viewModel.saveImage(image, for: ticketId)
                },
                onLoadImage: { ticketImage, ticketId in
                    await viewModel.loadImage(for: ticketImage, ticketId: ticketId)
                },
                onDeleteImage: { ticketImage, ticketId in
                    try await viewModel.deleteImage(ticketImage, for: ticketId)
                }
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Theme.space3) {
            Image(systemName: "ticket")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)

            Text("Tickets")
                .font(.system(size: Theme.fontLG, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            // Ticket count badge
            if !viewModel.tickets.isEmpty {
                Text("\(viewModel.tickets.count)")
                    .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accentMuted)
                    .cornerRadius(4)
            }

            Spacer()

            // Create button
            Button(action: { showingCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent)
                    .cornerRadius(Theme.radiusSmall)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .help("Create ticket")
            .pointingHandCursor()

            // Refresh button
            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 24, height: 24)
                    .background(Theme.surface)
                    .cornerRadius(Theme.radiusSmall)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .help("Refresh")
            .pointingHandCursor()
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: Theme.space3) {
            // Status filters
            HStack(spacing: Theme.space1) {
                ForEach(TicketFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.rawValue,
                        count: countForFilter(filter),
                        isSelected: viewModel.filter == filter,
                        action: { viewModel.filter = filter }
                    )
                }
            }

            Spacer()

            // Sort picker
            Menu {
                ForEach(TicketSort.allCases, id: \.self) { sort in
                    Button(action: { viewModel.sort = sort }) {
                        HStack {
                            Text(sort.rawValue)
                            if viewModel.sort == sort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .medium))
                    Text(viewModel.sort.rawValue)
                        .font(.system(size: Theme.fontXS, weight: .medium))
                }
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, Theme.space2)
                .padding(.vertical, 4)
                .background(Theme.surface)
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .pointingHandCursor()
        }
    }

    private func countForFilter(_ filter: TicketFilter) -> Int? {
        switch filter {
        case .all: return viewModel.tickets.isEmpty ? nil : viewModel.tickets.count
        case .open: return viewModel.openCount > 0 ? viewModel.openCount : nil
        case .inProgress: return viewModel.inProgressCount > 0 ? viewModel.inProgressCount : nil
        case .done: return viewModel.doneCount > 0 ? viewModel.doneCount : nil
        }
    }

    // MARK: - Ticket List

    private var ticketListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredTickets.enumerated()), id: \.element.id) { index, ticket in
                    TicketRowView(
                        ticket: ticket,
                        onSelect: { selectedTicketForEditing = ticket },
                        onStatusChange: { newStatus in
                            Task {
                                try? await viewModel.setStatus(newStatus, for: ticket)
                            }
                        }
                    )

                    if index < viewModel.filteredTickets.count - 1 {
                        Divider()
                            .background(Theme.border.opacity(0.5))
                    }
                }
            }
            .padding(.vertical, Theme.space2)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: Theme.space4) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Loading tickets...")
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
                Text("Failed to load tickets")
                    .font(.system(size: Theme.fontLG, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(error.localizedDescription)
                    .font(.system(size: Theme.fontBase))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.space8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: Theme.space5) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceHover)
                    .frame(width: 72, height: 72)

                Image(systemName: "ticket")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(spacing: Theme.space2) {
                if viewModel.filter != .all && viewModel.tickets.isEmpty == false {
                    // Filtered but no matches
                    Text("No \(viewModel.filter.rawValue.lowercased()) tickets")
                        .font(.system(size: Theme.fontLG, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text("Try changing the filter or create a new ticket")
                        .font(.system(size: Theme.fontBase))
                        .foregroundColor(Theme.textTertiary)
                } else {
                    // No tickets at all
                    Text("No tickets yet")
                        .font(.system(size: Theme.fontLG, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Text("Create a ticket to track tasks for this project")
                        .font(.system(size: Theme.fontBase))
                        .foregroundColor(Theme.textTertiary)

                    Button(action: { showingCreateSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Create Ticket")
                                .font(.system(size: Theme.fontSM, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.space4)
                        .padding(.vertical, Theme.space2)
                        .background(Theme.accent)
                        .cornerRadius(Theme.radiusSmall)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.space2)
                    .pointingHandCursor()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Button

private struct FilterButton: View {
    let title: String
    let count: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: Theme.fontXS, weight: isSelected ? .semibold : .medium))

                if let count = count {
                    Text("\(count)")
                        .font(.system(size: Theme.fontXS, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
                }
            }
            .foregroundColor(isSelected ? Theme.accent : (isHovered ? Theme.textSecondary : Theme.textTertiary))
            .padding(.horizontal, Theme.space2)
            .padding(.vertical, 4)
            .background(isSelected ? Theme.accentMuted : (isHovered ? Theme.surfaceHover : .clear))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointingHandCursor()
    }
}

#Preview {
    TicketsView(project: Project(name: "Demo", path: "/Users"))
        .frame(width: 500, height: 400)
}
