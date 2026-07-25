import SwiftUI

private enum TicketViewMode: String, CaseIterable {
    case list
    case board

    var title: String {
        rawValue.capitalized
    }
}

/// View for browsing and managing tickets in a project
struct TicketsView: View {
    let project: Project
    var worktreePath: String? = nil
    @StateObject private var viewModel = TicketsBrowserViewModel()
    @AppStorage("tickets.viewMode") private var viewMode: TicketViewMode = .list

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
            } else if viewModel.tickets.isEmpty
                        || (viewMode == .list && viewModel.filteredTickets.isEmpty) {
                emptyStateView
            } else if viewMode == .board {
                ticketBoardView
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
                availableTickets: viewModel.tickets,
                onSave: { title, description, status, images, dependencies in
                    try await viewModel.createTicket(
                        title: title,
                        description: description,
                        status: status,
                        images: images,
                        dependencies: dependencies
                    )
                },
                onCreateWithImages: { title, description, status, images, dependencies in
                    try await viewModel.createTicket(
                        title: title,
                        description: description,
                        status: status,
                        attachedImages: images,
                        dependencies: dependencies
                    )
                },
                onSaveImage: { image, ticketId in
                    try await viewModel.saveImage(image, for: ticketId)
                }
            )
        }
        .sheet(item: $selectedTicketForEditing) { ticket in
            TicketEditorView(
                existingTicket: ticket,
                availableTickets: viewModel.tickets.filter { $0.id != ticket.id },
                onSave: { title, description, status, images, dependencies in
                    let updated = ticket.updated(
                        title: title,
                        description: description,
                        status: status,
                        images: images,
                        dependencies: dependencies
                    )
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

            TicketViewSwitcher(selection: $viewMode)

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
            if viewMode == .list {
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
            } else {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 9, weight: .semibold))

                    Text("Drag cards to move work")
                        .font(.system(size: Theme.fontXS, weight: .medium))
                }
                .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            sortPicker
        }
    }

    private var sortPicker: some View {
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
                        dependencySummary: viewModel.dependencySummary(for: ticket),
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

    // MARK: - Ticket Board

    private var ticketBoardView: some View {
        GeometryReader { proxy in
            let boardPadding = Theme.space3
            let columnSpacing = Theme.space3
            let compactColumnWidth = min(244, max(208, proxy.size.width * 0.58))
            let availableColumnWidth = (
                proxy.size.width
                    - (boardPadding * 2)
                    - (columnSpacing * CGFloat(TicketStatus.allCases.count - 1))
            ) / CGFloat(TicketStatus.allCases.count)
            let columnWidth = proxy.size.width >= 780
                ? min(420, max(208, availableColumnWidth))
                : compactColumnWidth

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    ForEach(TicketStatus.allCases, id: \.rawValue) { status in
                        TicketBoardColumn(
                            status: status,
                            tickets: viewModel.sortedTickets.filter { $0.status == status },
                            dependencySummary: viewModel.dependencySummary,
                            onSelect: { selectedTicketForEditing = $0 },
                            onMove: moveTicket
                        )
                        .frame(
                            width: columnWidth,
                            height: max(1, proxy.size.height - (Theme.space3 * 2))
                        )
                    }
                }
                .padding(boardPadding)
            }
        }
    }

    private func moveTicket(_ ticketId: Int, to status: TicketStatus) {
        guard let ticket = viewModel.tickets.first(where: { $0.id == ticketId }),
              ticket.status != status else {
            return
        }

        Task {
            try? await viewModel.setStatus(status, for: ticket)
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

// MARK: - View Switcher

private struct TicketViewSwitcher: View {
    @Binding var selection: TicketViewMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TicketViewMode.allCases, id: \.rawValue) { mode in
                Button(action: { selection = mode }) {
                    Text(mode.title)
                        .font(.system(size: Theme.fontXS, weight: .semibold))
                        .foregroundColor(selection == mode ? Theme.textPrimary : Theme.textTertiary)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
                        .background(selection == mode ? Theme.surfaceActive : .clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(mode.title) view")
                .pointingHandCursor()
            }
        }
        .padding(2)
        .background(Theme.surface)
        .cornerRadius(Theme.radiusSmall)
    }
}

// MARK: - Board Column

private struct TicketBoardColumn: View {
    let status: TicketStatus
    let tickets: [Ticket]
    let dependencySummary: (Ticket) -> TicketDependencySummary
    let onSelect: (Ticket) -> Void
    let onMove: (Int, TicketStatus) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.space2) {
                Image(systemName: status.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(status.boardColor)

                Text(status.displayName)
                    .font(.system(size: Theme.fontSM, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text("\(tickets.count)")
                    .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.surface)
                    .cornerRadius(4)
            }
            .padding(.horizontal, Theme.space3)
            .frame(height: 38)

            Divider()
                .background(Theme.borderSubtle)

            if tickets.isEmpty {
                boardEmptyState
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: Theme.space2) {
                        ForEach(tickets) { ticket in
                            TicketBoardCard(
                                ticket: ticket,
                                dependencySummary: dependencySummary(ticket),
                                onSelect: { onSelect(ticket) },
                                onMove: { onMove(ticket.id, $0) }
                            )
                        }
                    }
                    .padding(Theme.space2)
                }
            }
        }
        .background(
            isDropTargeted
                ? status.boardColor.opacity(0.08)
                : Theme.sidebarBackground.opacity(0.72)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(
                    isDropTargeted ? status.boardColor.opacity(0.7) : Theme.border,
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        }
        .cornerRadius(Theme.radius)
        .dropDestination(for: String.self) { identifiers, _ in
            guard let ticketId = identifiers.compactMap({ Int($0) }).first else {
                return false
            }
            onMove(ticketId, status)
            return true
        } isTargeted: {
            isDropTargeted = $0
        }
    }

    private var boardEmptyState: some View {
        VStack(spacing: Theme.space2) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "arrow.down.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isDropTargeted ? status.boardColor : Theme.textMuted)

            Text(isDropTargeted ? "Move to \(status.displayName)" : "Drop tickets here")
                .font(.system(size: Theme.fontXS, weight: .medium))
                .foregroundColor(isDropTargeted ? Theme.textSecondary : Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.space4)
    }
}

// MARK: - Board Card

private struct TicketBoardCard: View {
    let ticket: Ticket
    let dependencySummary: TicketDependencySummary
    let onSelect: () -> Void
    let onMove: (TicketStatus) -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Theme.space2) {
                HStack(spacing: Theme.space2) {
                    Text("#\(ticket.id)")
                        .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textTertiary)

                    Spacer()

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isHovered ? Theme.textTertiary : Theme.textMuted.opacity(0.55))
                }

                Text(ticket.title)
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Theme.space2) {
                    if dependencySummary.state != .none {
                        TicketDependencyBadge(summary: dependencySummary, compact: true)
                    }

                    if !ticket.images.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "photo")
                                .font(.system(size: 8, weight: .semibold))
                            Text("\(ticket.images.count)")
                                .font(.system(size: Theme.fontXS, weight: .medium))
                        }
                        .foregroundColor(Theme.textMuted)
                    }

                    Spacer()

                    Text(relativeTime(from: ticket.updatedAt))
                        .font(.system(size: Theme.fontXS))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .padding(Theme.space3)
            .background(isHovered ? Theme.surfaceHover : Theme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusSmall)
                    .stroke(isHovered ? Theme.borderFocus : Theme.borderSubtle, lineWidth: 1)
            }
            .cornerRadius(Theme.radiusSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .draggable(String(ticket.id)) {
            HStack(spacing: Theme.space2) {
                Text("#\(ticket.id)")
                    .font(.system(size: Theme.fontXS, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
                Text(ticket.title)
                    .font(.system(size: Theme.fontSM, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Theme.space3)
            .padding(.vertical, Theme.space2)
            .frame(width: 200, alignment: .leading)
            .background(Theme.surfaceElevated)
            .cornerRadius(Theme.radiusSmall)
        }
        .contextMenu {
            Text("Move to")

            ForEach(TicketStatus.allCases, id: \.rawValue) { status in
                Button {
                    onMove(status)
                } label: {
                    Label(status.displayName, systemImage: status.icon)
                }
                .disabled(status == ticket.status)
            }
        }
        .help("Open ticket #\(ticket.id). Drag to change status.")
        .pointingHandCursor()
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension TicketStatus {
    var boardColor: Color {
        switch self {
        case .open:
            return Theme.accent
        case .inProgress:
            return Theme.warning
        case .done:
            return Theme.success
        }
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
