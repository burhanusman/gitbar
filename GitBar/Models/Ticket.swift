import Foundation

/// Represents an image attachment on a ticket
struct TicketImage: Identifiable, Codable, Equatable {
    let id: String
    let filename: String
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case filename
        case addedAt = "added_at"
    }

    /// Creates a new ticket image with a generated ID
    static func create(filename: String) -> TicketImage {
        TicketImage(
            id: "img-\(UUID().uuidString.prefix(8).lowercased())",
            filename: filename,
            addedAt: Date()
        )
    }
}

/// Status of a ticket
enum TicketStatus: String, Codable, CaseIterable {
    case open = "open"
    case inProgress = "in_progress"
    case done = "done"

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .inProgress: return "In Progress"
        case .done: return "Done"
        }
    }

    var icon: String {
        switch self {
        case .open: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        }
    }
}

/// Represents a local ticket/issue stored in the project
struct Ticket: Identifiable, Codable, Equatable {
    let id: Int
    var title: String
    var description: String
    var status: TicketStatus
    var images: [TicketImage]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case status
        case images
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(TicketStatus.self, forKey: .status)
        // Handle missing images field for backwards compatibility
        images = try container.decodeIfPresent([TicketImage].self, forKey: .images) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(id: Int, title: String, description: String, status: TicketStatus, images: [TicketImage] = [], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.images = images
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Creates a new ticket with the given ID
    static func create(id: Int, title: String, description: String, status: TicketStatus = .open, images: [TicketImage] = []) -> Ticket {
        let now = Date()
        return Ticket(
            id: id,
            title: title,
            description: description,
            status: status,
            images: images,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Creates an updated copy of the ticket
    func updated(title: String? = nil, description: String? = nil, status: TicketStatus? = nil, images: [TicketImage]? = nil) -> Ticket {
        Ticket(
            id: self.id,
            title: title ?? self.title,
            description: description ?? self.description,
            status: status ?? self.status,
            images: images ?? self.images,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
}
