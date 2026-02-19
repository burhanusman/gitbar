import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "TicketsBrowser")

/// Filter options for ticket status
enum TicketFilter: String, CaseIterable {
    case all = "All"
    case open = "Open"
    case inProgress = "In Progress"
    case done = "Done"

    var status: TicketStatus? {
        switch self {
        case .all: return nil
        case .open: return .open
        case .inProgress: return .inProgress
        case .done: return .done
        }
    }
}

/// Sort options for tickets
enum TicketSort: String, CaseIterable {
    case recent = "Recent"
    case created = "Created"
}

/// ViewModel for browsing and managing tickets
@MainActor
class TicketsBrowserViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var filter: TicketFilter = .all
    @Published var sort: TicketSort = .recent

    private let ticketService = TicketService()
    private var projectPath: String?

    /// Filtered and sorted tickets based on current settings
    var filteredTickets: [Ticket] {
        var result = tickets

        // Apply filter
        if let status = filter.status {
            result = result.filter { $0.status == status }
        }

        // Apply sort
        switch sort {
        case .recent:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        return result
    }

    /// Count of open tickets
    var openCount: Int {
        tickets.filter { $0.status == .open }.count
    }

    /// Count of in-progress tickets
    var inProgressCount: Int {
        tickets.filter { $0.status == .inProgress }.count
    }

    /// Count of done tickets
    var doneCount: Int {
        tickets.filter { $0.status == .done }.count
    }

    /// Loads tickets from the given project path
    func loadTickets(at path: String) {
        logger.info("Loading tickets for: \(path)")
        projectPath = path
        isLoading = true
        error = nil

        Task {
            do {
                let loadedTickets = try await ticketService.loadTickets(at: path)
                self.tickets = loadedTickets
                self.isLoading = false
                logger.info("Loaded \(loadedTickets.count) tickets")
            } catch {
                logger.error("Failed to load tickets: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Refreshes the ticket list
    func refresh() {
        guard let path = projectPath else { return }
        loadTickets(at: path)
    }

    /// Returns the next available ticket ID
    var nextTicketId: Int {
        (tickets.map { $0.id }.max() ?? 0) + 1
    }

    /// Creates a new ticket
    func createTicket(title: String, description: String, status: TicketStatus = .open, images: [TicketImage] = []) async throws {
        guard let path = projectPath else { return }

        let ticket = Ticket.create(id: nextTicketId, title: title, description: description, status: status, images: images)
        try await ticketService.createTicket(ticket, at: path)

        // Reload to get the updated list
        let loadedTickets = try await ticketService.loadTickets(at: path)
        self.tickets = loadedTickets
    }

    /// Saves an image for a ticket (before or after creation)
    func saveImage(_ image: NSImage, for ticketId: Int) async throws -> TicketImage {
        guard let path = projectPath else {
            throw TicketServiceError.writeFailed("No project path set")
        }

        return try await ticketService.saveImage(image, for: ticketId, at: path)
    }

    /// Deletes an image for a ticket
    func deleteImage(_ ticketImage: TicketImage, for ticketId: Int) async throws {
        guard let path = projectPath else { return }

        try await ticketService.deleteImage(ticketImage, for: ticketId, at: path)
    }

    /// Loads an image for display
    func loadImage(for ticketImage: TicketImage, ticketId: Int) async -> NSImage? {
        guard let path = projectPath else { return nil }

        return await ticketService.loadImage(for: ticketImage, ticketId: ticketId, at: path)
    }

    /// Updates an existing ticket
    func updateTicket(_ ticket: Ticket) async throws {
        guard let path = projectPath else { return }

        try await ticketService.updateTicket(ticket, at: path)

        // Reload to get the updated list
        let loadedTickets = try await ticketService.loadTickets(at: path)
        self.tickets = loadedTickets
    }

    /// Changes the status of a ticket
    func setStatus(_ status: TicketStatus, for ticket: Ticket) async throws {
        let updated = ticket.updated(status: status)
        try await updateTicket(updated)
    }
}
