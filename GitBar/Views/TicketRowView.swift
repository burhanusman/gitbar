import SwiftUI

/// A row displaying a single ticket
struct TicketRowView: View {
    let ticket: Ticket
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
