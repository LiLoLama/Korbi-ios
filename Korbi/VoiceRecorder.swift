import Foundation
import AVFoundation

@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    enum RecorderError: LocalizedError {
        case permissionDenied
        case missingWebhook
        case missingFile
        case failedToSend(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Zugriff auf das Mikrofon wurde verweigert. Bitte erlaube Aufnahmen in den Einstellungen."
            case .missingWebhook:
                return "Es ist kein Webhook zum Senden der Aufnahme hinterlegt."
            case .missingFile:
                return "Die Aufnahme konnte nicht gefunden werden."
            case let .failedToSend(statusCode):
                return "Die Aufnahme konnte nicht gesendet werden (Fehlercode \(statusCode))."
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var isSending = false
    @Published var successMessage: String?
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var webhookURL: URL?
    private var householdID: UUID?

    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 12_000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    func configure(webhookURL: URL, householdID: UUID? = nil) {
        self.webhookURL = webhookURL
        self.householdID = householdID
    }

    func startRecording() {
        guard !isRecording, !isSending else { return }

        Task {
            do {
                guard let webhookURL else {
                    throw RecorderError.missingWebhook
                }

                self.webhookURL = webhookURL

                let session = AVAudioSession.sharedInstance()

                guard try await ensurePermission(for: session) else {
                    throw RecorderError.permissionDenied
                }

                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true, options: [])

                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("korbi-voice-\(UUID().uuidString).m4a")

                let recorder = try AVAudioRecorder(url: url, settings: recordingSettings)
                recorder.delegate = self
                recorder.record()

                await MainActor.run {
                    self.audioRecorder = recorder
                    self.recordingURL = url
                    self.isRecording = true
                    self.successMessage = nil
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.isRecording = false
                    self.audioRecorder = nil
                    self.recordingURL = nil
                    self.errorMessage = (error as? RecorderError)?.errorDescription ?? error.localizedDescription
                    self.scheduleErrorCleanup()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        guard let url = recordingURL else {
            errorMessage = RecorderError.missingFile.errorDescription
            scheduleErrorCleanup()
            return
        }

        recordingURL = nil
        sendRecording(at: url)
    }

    private func sendRecording(at url: URL) {
        guard let webhookURL else {
            errorMessage = RecorderError.missingWebhook.errorDescription
            scheduleErrorCleanup()
            return
        }

        isSending = true

        Task {
            do {
                let data = try Data(contentsOf: url)

                var request = URLRequest(url: webhookURL)
                request.httpMethod = "POST"

                let boundary = "Boundary-\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                var body = Data()
                let filename = url.lastPathComponent

                if let householdID {
                    body.appendTextFormField(name: "household_id", value: householdID.uuidString, boundary: boundary)
                }

                body.appendFormFieldBoundary(boundary)
                body.appendFormFieldDisposition(name: "file", filename: filename, contentType: "audio/mp4")
                body.append(data)
                body.appendLineBreak()
                body.appendClosingBoundary(boundary)

                let (_, response) = try await URLSession.shared.upload(for: request, from: body)

                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    throw RecorderError.failedToSend(statusCode: httpResponse.statusCode)
                }

                try? FileManager.default.removeItem(at: url)

                await MainActor.run {
                    self.isSending = false
                    self.successMessage = "Aufnahme erfolgreich gesendet"
                    self.scheduleSuccessCleanup()
                    NotificationCenter.default.post(name: .voiceRecordingDidSend, object: nil)
                }

                try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                await MainActor.run {
                    self.isSending = false
                    self.errorMessage = (error as? RecorderError)?.errorDescription ?? error.localizedDescription
                    self.scheduleErrorCleanup()
                }

                try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            }
        }
    }

    private func ensurePermission(for session: AVAudioSession) async throws -> Bool {
        switch session.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func scheduleSuccessCleanup() {
        let currentMessage = successMessage
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.successMessage == currentMessage else { return }
            self.successMessage = nil
        }
    }

    private func scheduleErrorCleanup() {
        let currentMessage = errorMessage
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self, self.errorMessage == currentMessage else { return }
            self.errorMessage = nil
        }
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            scheduleErrorCleanup()
        }
    }
}

private extension Data {
    mutating func appendTextFormField(name: String, value: String, boundary: String) {
        appendFormFieldBoundary(boundary)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        appendLineBreak()
    }

    mutating func appendFormFieldBoundary(_ boundary: String) {
        append("--\(boundary)\r\n")
    }

    mutating func appendFormFieldDisposition(name: String, filename: String, contentType: String) {
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
    }

    mutating func appendLineBreak() {
        append("\r\n")
    }

    mutating func appendClosingBoundary(_ boundary: String) {
        append("--\(boundary)--\r\n")
    }

    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension Notification.Name {
    static let voiceRecordingDidSend = Notification.Name("voiceRecordingDidSend")
}
