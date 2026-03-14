import Foundation
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "OpenAIService")

/// Errors that can occur during OpenAI API operations
enum OpenAIServiceError: Error, LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(String)
    case invalidResponse
    case apiError(String)
    case rateLimited
    case audioTooLarge
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured. Add it in Settings."
        case .invalidAPIKey:
            return "Invalid OpenAI API key"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .rateLimited:
            return "Rate limited by OpenAI. Please wait and try again."
        case .audioTooLarge:
            return "Audio file too large (max 25MB)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

/// Service for OpenAI API interactions (Whisper and GPT)
actor OpenAIService {
    static let shared = OpenAIService()

    private let keychainService = KeychainService.shared
    private let session: URLSession

    // API endpoints
    private let whisperURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let chatURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    // Models
    private let whisperModel = "whisper-1"
    private let chatModel = "gpt-4o-mini"

    // Limits
    private let maxAudioSize = 25 * 1024 * 1024 // 25MB

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - API Key

    private func getAPIKey() throws -> String {
        guard let key = keychainService.getOpenAIAPIKey() else {
            throw OpenAIServiceError.noAPIKey
        }
        return key
    }

    // MARK: - Whisper Transcription

    /// Transcribes audio data to text using OpenAI Whisper API
    /// - Parameter audioData: Audio data in m4a, mp3, wav, or similar format
    /// - Returns: Transcribed text
    func transcribe(audioData: Data) async throws -> String {
        let apiKey = try getAPIKey()

        guard audioData.count <= maxAudioSize else {
            throw OpenAIServiceError.audioTooLarge
        }

        logger.debug("Transcribing audio: \(audioData.count) bytes")

        // Build multipart form request
        let boundary = UUID().uuidString
        var request = URLRequest(url: whisperURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(whisperModel)\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw OpenAIServiceError.invalidAPIKey
        }

        if httpResponse.statusCode == 429 {
            throw OpenAIServiceError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Whisper API error: \(errorMessage)")
            throw OpenAIServiceError.transcriptionFailed(errorMessage)
        }

        // Parse response
        struct WhisperResponse: Decodable {
            let text: String
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(WhisperResponse.self, from: data)

        logger.debug("Transcription complete: \(result.text.prefix(50))...")
        return result.text
    }

    // MARK: - GPT Commit Message Generation

    /// Generates a commit message from a git diff using GPT
    /// - Parameter diff: The git diff output for staged changes
    /// - Returns: A suggested commit message
    func generateCommitMessage(diff: String) async throws -> String {
        let apiKey = try getAPIKey()

        // Truncate diff if too long (GPT has context limits)
        let maxDiffLength = 8000
        let truncatedDiff = diff.count > maxDiffLength
            ? String(diff.prefix(maxDiffLength)) + "\n... (truncated)"
            : diff

        logger.debug("Generating commit message for diff: \(truncatedDiff.count) chars")

        let systemPrompt = """
            You are a helpful assistant that generates concise, conventional git commit messages.
            Follow the conventional commits format: type(scope): description
            Types: feat, fix, docs, style, refactor, test, chore
            Keep the first line under 72 characters.
            Only output the commit message, nothing else.
            """

        let userPrompt = """
            Generate a commit message for the following changes:

            \(truncatedDiff)
            """

        let requestBody: [String: Any] = [
            "model": chatModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 100,
            "temperature": 0.3
        ]

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw OpenAIServiceError.invalidAPIKey
        }

        if httpResponse.statusCode == 429 {
            throw OpenAIServiceError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("GPT API error: \(errorMessage)")
            throw OpenAIServiceError.apiError(errorMessage)
        }

        // Parse response
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(ChatResponse.self, from: data)

        guard let message = result.choices.first?.message.content else {
            throw OpenAIServiceError.invalidResponse
        }

        let commitMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.debug("Generated commit message: \(commitMessage)")
        return commitMessage
    }
}
