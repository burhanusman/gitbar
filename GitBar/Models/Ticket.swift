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
    var dependencies: [Int]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case status
        case images
        case dependencies
        case dependsOn = "depends_on"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ticketId = try container.decode(Int.self, forKey: .id)
        id = ticketId
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(TicketStatus.self, forKey: .status)
        // Handle missing images field for backwards compatibility
        images = try container.decodeIfPresent([TicketImage].self, forKey: .images) ?? []
        // `depends_on` was used by a few hand-authored boards before the schema
        // was formalized. Read both forms, but always write `dependencies`.
        let decodedDependencies =
            try container.decodeIfPresent([Int].self, forKey: .dependencies)
                ?? container.decodeIfPresent([Int].self, forKey: .dependsOn)
                ?? []
        dependencies = Self.normalizedDependencies(decodedDependencies.filter { $0 != ticketId })
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(status, forKey: .status)
        try container.encode(images, forKey: .images)
        try container.encode(dependencies, forKey: .dependencies)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    init(id: Int, title: String, description: String, status: TicketStatus, images: [TicketImage] = [], dependencies: [Int] = [], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.images = images
        self.dependencies = Self.normalizedDependencies(dependencies.filter { $0 != id })
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Creates a new ticket with the given ID
    static func create(id: Int, title: String, description: String, status: TicketStatus = .open, images: [TicketImage] = [], dependencies: [Int] = []) -> Ticket {
        let now = Date()
        return Ticket(
            id: id,
            title: title,
            description: description,
            status: status,
            images: images,
            dependencies: dependencies,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Creates an updated copy of the ticket
    func updated(title: String? = nil, description: String? = nil, status: TicketStatus? = nil, images: [TicketImage]? = nil, dependencies: [Int]? = nil) -> Ticket {
        Ticket(
            id: self.id,
            title: title ?? self.title,
            description: description ?? self.description,
            status: status ?? self.status,
            images: images ?? self.images,
            dependencies: dependencies ?? self.dependencies,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }

    private static func normalizedDependencies(_ dependencies: [Int]) -> [Int] {
        Array(Set(dependencies.filter { $0 > 0 })).sorted()
    }
}
