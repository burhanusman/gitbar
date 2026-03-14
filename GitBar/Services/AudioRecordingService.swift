import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.gitbar.app", category: "AudioRecordingService")

/// Errors that can occur during audio recording
enum AudioRecordingError: Error, LocalizedError {
    case microphonePermissionDenied
    case recordingFailed(String)
    case noRecordingInProgress
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access denied. Enable in System Settings > Privacy & Security > Microphone."
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .noRecordingInProgress:
            return "No recording in progress"
        case .fileNotFound:
            return "Recording file not found"
        }
    }
}

/// Service for recording audio from the microphone
/// Uses AVFoundation to record audio in m4a format optimized for Whisper API
@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var hasPermission = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var startTime: Date?

    override init() {
        super.init()
        checkPermissionStatus()
    }

    // MARK: - Permissions

    /// Checks the current microphone permission status
    func checkPermissionStatus() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        hasPermission = (status == .authorized)
    }

    /// Requests microphone permission
    /// - Returns: Whether permission was granted
    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            hasPermission = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                self.hasPermission = granted
            }
            return granted
        case .denied, .restricted:
            hasPermission = false
            return false
        @unknown default:
            hasPermission = false
            return false
        }
    }

    // MARK: - Recording

    /// Starts recording audio
    /// - Throws: AudioRecordingError if recording fails
    func startRecording() throws {
        guard hasPermission else {
            throw AudioRecordingError.microphonePermissionDenied
        }

        // Create temporary file URL for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "gitbar_recording_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        recordingURL = fileURL

        // Audio settings optimized for Whisper API
        // 16kHz mono AAC - good quality while keeping file size small
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()

            guard audioRecorder?.record() == true else {
                throw AudioRecordingError.recordingFailed("Failed to start recording")
            }

            isRecording = true
            startTime = Date()
            recordingDuration = 0

            // Start level metering timer
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAudioLevel()
                }
            }

            // Start duration timer
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateDuration()
                }
            }

            logger.debug("Started recording to: \(fileURL.path)")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            throw AudioRecordingError.recordingFailed(error.localizedDescription)
        }
    }

    /// Stops recording and returns the audio data
    /// - Returns: The recorded audio data, or nil if no recording was in progress
    func stopRecording() -> Data? {
        guard isRecording, let recorder = audioRecorder else {
            return nil
        }

        recorder.stop()
        isRecording = false

        // Stop timers
        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        audioLevel = 0

        guard let url = recordingURL else {
            return nil
        }

        logger.debug("Stopped recording, duration: \(self.recordingDuration)s")

        // Read the recorded file
        do {
            let data = try Data(contentsOf: url)

            // Clean up the temporary file
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil

            logger.debug("Recording size: \(data.count) bytes")
            return data
        } catch {
            logger.error("Failed to read recording: \(error.localizedDescription)")
            return nil
        }
    }

    /// Cancels the current recording without returning data
    func cancelRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        isRecording = false

        levelTimer?.invalidate()
        levelTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        audioLevel = 0
        recordingDuration = 0

        // Delete the temporary file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        logger.debug("Recording cancelled")
    }

    // MARK: - Private Methods

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, isRecording else {
            audioLevel = 0
            return
        }

        recorder.updateMeters()
        // Convert dB to linear scale (0-1)
        let dB = recorder.averagePower(forChannel: 0)
        // Normalize from -60dB to 0dB range
        let normalizedLevel = max(0, (dB + 60) / 60)
        audioLevel = normalizedLevel
    }

    private func updateDuration() {
        guard let start = startTime, isRecording else { return }
        recordingDuration = Date().timeIntervalSince(start)
    }

    /// Formats the recording duration as MM:SS
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
