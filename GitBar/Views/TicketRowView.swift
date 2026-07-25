import SwiftUI

/// A row displaying a single ticket
struct TicketRowView: View {
    let ticket: Ticket
    var dependencySummary: TicketDependencySummary = .none
    let onSelect: () -> Void
    let onStatusChange: (TicketStatus) -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.space3) {
                // Status indicator button
                statusButton

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.title)
                        .font(.system(size: Theme.fontSM, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Theme.space2) {
                        // Status badge
                        Text(ticket.status.displayName)
                            .font(.system(size: Theme.fontXS, weight: .medium))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.15))
                            .cornerRadius(4)

                        // Image count indicator
                        if !ticket.images.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "photo")
                                    .font(.system(size: 9, weight: .medium))
                                Text("\(ticket.images.count)")
                                    .font(.system(size: Theme.fontXS, weight: .medium))
                            }
                            .foregroundColor(Theme.textMuted)
                        }

                        if dependencySummary.state != .none {
                            TicketDependencyBadge(summary: dependencySummary)
                        }

                        // Relative time
                        Text(relativeTime(from: ticket.updatedAt))
                            .font(.system(size: Theme.fontXS))
                            .foregroundColor(Theme.textMuted)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, Theme.space4)
            .padding(.vertical, Theme.space3)
            .background(isHovered ? Theme.surfaceHover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .pointingHandCursor()
    }

    // MARK: - Status Button

    private var statusButton: some View {
        Button(action: {
            // Cycle through statuses
            let nextStatus: TicketStatus
            switch ticket.status {
            case .open:
                nextStatus = .inProgress
            case .inProgress:
                nextStatus = .done
            case .done:
                nextStatus = .open
            }
            onStatusChange(nextStatus)
        }) {
            Image(systemName: ticket.status.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(statusColor)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Change status")
        .pointingHandCursor()
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch ticket.status {
        case .open:
            return Theme.accent
        case .inProgress:
            return Theme.warning
        case .done:
            return Theme.success
        }
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Dependency Badge

struct TicketDependencyBadge: View {
    let summary: TicketDependencySummary
    var compact = false

    private var color: Color {
        switch summary.state {
        case .none:
            return Theme.textMuted
        case .ready:
            return Theme.success
        case .blocked:
            return Theme.warning
        case .missing:
            return Theme.error
        }
    }

    private var icon: String {
        switch summary.state {
        case .none:
            return "link"
        case .ready:
            return "checkmark.circle.fill"
        case .blocked:
            return "pause.circle.fill"
        case .missing:
            return "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        if compact {
            switch summary.state {
            case .none:
                return ""
            case .ready:
                return "Ready"
            case .blocked:
                return "Blocked"
            case .missing:
                return "Missing"
            }
        }

        switch summary.state {
        case .none:
            return ""
        case .ready:
            return "Ready · \(formattedIds(summary.dependencyIds))"
        case .blocked:
            return "Blocked by \(formattedIds(summary.incompleteIds))"
        case .missing:
            return "Missing \(formattedIds(summary.missingIds))"
        }
    }

    private var helpText: String {
        let dependencyList = summary.dependencyIds.map { "#\($0)" }.joined(separator: ", ")
        switch summary.state {
        case .none:
            return "No dependencies"
        case .ready:
            return "All dependencies are done: \(dependencyList)"
        case .blocked:
            return "Waiting for \(summary.incompleteIds.map { "#\($0)" }.joined(separator: ", "))"
        case .missing:
            return "Referenced tickets could not be found: \(summary.missingIds.map { "#\($0)" }.joined(separator: ", "))"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))

            Text(label)
                .font(.system(size: Theme.fontXS, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .cornerRadius(4)
        .help(helpText)
    }

    private func formattedIds(_ ids: [Int]) -> String {
        let visibleIds = ids.prefix(2).map { "#\($0)" }.joined(separator: ", ")
        let remainingCount = ids.count - min(ids.count, 2)
        return remainingCount > 0 ? "\(visibleIds) +\(remainingCount)" : visibleIds
    }
}

#Preview {
    VStack(spacing: 0) {
        TicketRowView(
            ticket: Ticket.create(id: 1, title: "Fix login bug", description: "The login form fails"),
            onSelect: {},
            onStatusChange: { _ in }
        )
        Divider()
        TicketRowView(
            ticket: Ticket.create(id: 2, title: "Add dark mode", description: "").updated(status: .inProgress),
            onSelect: {},
            onStatusChange: { _ in }
        )
        Divider()
        TicketRowView(
            ticket: Ticket.create(id: 3, title: "Update README", description: "").updated(status: .done),
            onSelect: {},
            onStatusChange: { _ in }
        )
    }
    .frame(width: 400)
    .background(Theme.background)
}
