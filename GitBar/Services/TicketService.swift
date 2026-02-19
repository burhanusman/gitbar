import Foundation
import os.log
import AppKit

private let logger = Logger(subsystem: "com.gitbar.app", category: "TicketService")

/// Errors that can occur during ticket operations
enum TicketServiceError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case writeFailed(String)
    case readFailed(String)
    case encodingFailed
    case decodingFailed(String)
    case imageSaveFailed(String)
    case imageNotFound(String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
        case .writeFailed(let message):
            return "Failed to write tickets: \(message)"
        case .readFailed(let message):
            return "Failed to read tickets: \(message)"
        case .encodingFailed:
            return "Failed to encode ticket"
        case .decodingFailed(let line):
            return "Failed to decode ticket: \(line)"
        case .imageSaveFailed(let message):
            return "Failed to save image: \(message)"
        case .imageNotFound(let path):
            return "Image not found: \(path)"
        }
    }
}

/// Service for managing local tickets stored in JSONL format
actor TicketService {
    private let fileManager: FileManager

    /// The directory name for GitBar data
    private let gitbarDirectory = ".gitbar"

    /// The subdirectory for ticket images
    private let imagesDirectory = "images"

    /// The filename for tickets
    private let ticketsFilename = "tickets.jsonl"

    /// JSON encoder configured for tickets
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    /// JSON decoder configured for tickets
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Returns the path to the tickets file for a given project
    func ticketsFilePath(for projectPath: String) -> String {
        let gitbarPath = (projectPath as NSString).appendingPathComponent(gitbarDirectory)
        return (gitbarPath as NSString).appendingPathComponent(ticketsFilename)
    }

    /// Returns the modification date of the tickets file
    func fileModificationDate(for projectPath: String) -> Date? {
        let path = ticketsFilePath(for: projectPath)
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let modDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return modDate
    }

    /// Loads all tickets from the JSONL file, deduplicating by ID (keeps latest)
    func loadTickets(at projectPath: String) async throws -> [Ticket] {
        let filePath = ticketsFilePath(for: projectPath)
        logger.debug("Loading tickets from: \(filePath)")

        guard fileManager.fileExists(atPath: filePath) else {
            logger.debug("No tickets file found, returning empty list")
            return []
        }

        guard let data = fileManager.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            throw TicketServiceError.readFailed("Could not read file content")
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var ticketsByID: [Int: Ticket] = [:]
        var parseErrors = 0

        for line in lines {
            guard let lineData = line.data(using: .utf8) else {
                parseErrors += 1
                continue
            }

            do {
                let ticket = try decoder.decode(Ticket.self, from: lineData)
                // Keep the latest version (last occurrence) of each ticket
                ticketsByID[ticket.id] = ticket
            } catch {
                logger.warning("Failed to parse ticket line: \(line.prefix(50))...")
                parseErrors += 1
            }
        }

        if parseErrors > 0 {
            logger.warning("Skipped \(parseErrors) malformed ticket lines")
        }

        let tickets = Array(ticketsByID.values)
        logger.debug("Loaded \(tickets.count) tickets")
        return tickets
    }

    /// Creates a new ticket by appending to the JSONL file
    func createTicket(_ ticket: Ticket, at projectPath: String) async throws {
        let filePath = ticketsFilePath(for: projectPath)
        logger.debug("Creating ticket: \(ticket.id) at \(filePath)")

        // Ensure directory exists
        let dirPath = (filePath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: dirPath) {
            do {
                try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
                logger.debug("Created .gitbar directory")
            } catch {
                throw TicketServiceError.directoryCreationFailed(dirPath)
            }
        }

        // Encode ticket to JSON line
        guard let jsonData = try? encoder.encode(ticket),
              var jsonLine = String(data: jsonData, encoding: .utf8) else {
            throw TicketServiceError.encodingFailed
        }

        // Append newline
        jsonLine += "\n"

        // Append to file (create if needed)
        if fileManager.fileExists(atPath: filePath) {
            // Append to existing file
            guard let fileHandle = FileHandle(forWritingAtPath: filePath) else {
                throw TicketServiceError.writeFailed("Could not open file for writing")
            }
            defer { try? fileHandle.close() }

            try fileHandle.seekToEnd()
            guard let lineData = jsonLine.data(using: .utf8) else {
                throw TicketServiceError.encodingFailed
            }
            try fileHandle.write(contentsOf: lineData)
        } else {
            // Create new file
            guard let lineData = jsonLine.data(using: .utf8) else {
                throw TicketServiceError.encodingFailed
            }
            fileManager.createFile(atPath: filePath, contents: lineData)
        }

        logger.debug("Ticket created: \(ticket.id)")
    }

    /// Updates a ticket by appending the updated version (dedup happens on load)
    func updateTicket(_ ticket: Ticket, at projectPath: String) async throws {
        // Updates are implemented as appends - the latest version wins on load
        try await createTicket(ticket, at: projectPath)
        logger.debug("Ticket updated: \(ticket.id)")
    }

    /// Compacts the tickets file by removing duplicate entries
    /// Call this periodically to clean up the file
    func compactTickets(at projectPath: String) async throws {
        let tickets = try await loadTickets(at: projectPath)
        let filePath = ticketsFilePath(for: projectPath)

        // Rewrite file with deduplicated tickets
        var content = ""
        for ticket in tickets {
            guard let jsonData = try? encoder.encode(ticket),
                  let jsonLine = String(data: jsonData, encoding: .utf8) else {
                continue
            }
            content += jsonLine + "\n"
        }

        guard let data = content.data(using: .utf8) else {
            throw TicketServiceError.encodingFailed
        }

        try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
        logger.debug("Compacted tickets file: \(tickets.count) tickets")
    }

    // MARK: - Image Management

    /// Returns the path to the images directory for a given ticket
    func imagesDirectoryPath(for ticketId: Int, at projectPath: String) -> String {
        let gitbarPath = (projectPath as NSString).appendingPathComponent(gitbarDirectory)
        let imagesPath = (gitbarPath as NSString).appendingPathComponent(imagesDirectory)
        return (imagesPath as NSString).appendingPathComponent(String(ticketId))
    }

    /// Returns the full path to a specific image
    func imagePath(for image: TicketImage, ticketId: Int, at projectPath: String) -> String {
        let dirPath = imagesDirectoryPath(for: ticketId, at: projectPath)
        return (dirPath as NSString).appendingPathComponent(image.filename)
    }

    /// Saves an image for a ticket, returning the TicketImage metadata
    func saveImage(_ imageData: Data, originalFilename: String, for ticketId: Int, at projectPath: String) async throws -> TicketImage {
        let dirPath = imagesDirectoryPath(for: ticketId, at: projectPath)

        // Ensure directory exists
        if !fileManager.fileExists(atPath: dirPath) {
            do {
                try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
                logger.debug("Created images directory for ticket: \(ticketId)")
            } catch {
                throw TicketServiceError.directoryCreationFailed(dirPath)
            }
        }

        // Generate unique filename to avoid collisions
        let ext = (originalFilename as NSString).pathExtension
        let baseName = (originalFilename as NSString).deletingPathExtension
        let uniqueFilename = "\(baseName)-\(UUID().uuidString.prefix(6)).\(ext)"
        let filePath = (dirPath as NSString).appendingPathComponent(uniqueFilename)

        // Write image data
        do {
            try imageData.write(to: URL(fileURLWithPath: filePath))
            logger.debug("Saved image: \(uniqueFilename) for ticket: \(ticketId)")
        } catch {
            throw TicketServiceError.imageSaveFailed(error.localizedDescription)
        }

        return TicketImage.create(filename: uniqueFilename)
    }

    /// Saves an NSImage for a ticket
    func saveImage(_ image: NSImage, for ticketId: Int, at projectPath: String) async throws -> TicketImage {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw TicketServiceError.imageSaveFailed("Could not convert image to PNG")
        }

        return try await saveImage(pngData, originalFilename: "image.png", for: ticketId, at: projectPath)
    }

    /// Loads an image from disk
    func loadImage(for ticketImage: TicketImage, ticketId: Int, at projectPath: String) -> NSImage? {
        let path = imagePath(for: ticketImage, ticketId: ticketId, at: projectPath)
        return NSImage(contentsOfFile: path)
    }

    /// Deletes an image from disk
    func deleteImage(_ ticketImage: TicketImage, for ticketId: Int, at projectPath: String) throws {
        let path = imagePath(for: ticketImage, ticketId: ticketId, at: projectPath)

        guard fileManager.fileExists(atPath: path) else {
            logger.warning("Image not found for deletion: \(path)")
            return
        }

        try fileManager.removeItem(atPath: path)
        logger.debug("Deleted image: \(ticketImage.filename) for ticket: \(ticketId)")
    }

    /// Deletes all images for a ticket
    func deleteAllImages(for ticketId: Int, at projectPath: String) throws {
        let dirPath = imagesDirectoryPath(for: ticketId, at: projectPath)

        guard fileManager.fileExists(atPath: dirPath) else {
            return
        }

        try fileManager.removeItem(atPath: dirPath)
        logger.debug("Deleted all images for ticket: \(ticketId)")
    }
}
