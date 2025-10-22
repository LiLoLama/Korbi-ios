import Foundation
import Combine
import AVFoundation
import CryptoKit

protocol VoiceServicing {
  var statePublisher: AnyPublisher<VoiceSessionState, Never> { get }
  func startRecording(householdID: UUID, listID: UUID, userID: UUID) async throws
  func stopRecording() async throws
  func cancelRecording()
}

enum VoiceServiceError: Error {
  case recorderUnavailable
  case uploadFailed
  case invalidResponse
}

final class VoiceService: NSObject, VoiceServicing, AVAudioRecorderDelegate {
  private let configuration: AppConfiguration
  private let signer: HMACSigning
  private let urlSession: URLSession
  private let stateSubject = CurrentValueSubject<VoiceSessionState, Never>(VoiceSessionState())

  private var recorder: AVAudioRecorder?
  private var currentMeta: (household: UUID, list: UUID, user: UUID)?

  var statePublisher: AnyPublisher<VoiceSessionState, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  init(configuration: AppConfiguration, signer: HMACSigning, urlSession: URLSession) {
    self.configuration = configuration
    self.signer = signer
    self.urlSession = urlSession
    super.init()
  }

  func startRecording(householdID: UUID, listID: UUID, userID: UUID) async throws {
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
    recorder = try AVAudioRecorder(url: fileURL, settings: settings)
    recorder?.delegate = self
    guard recorder?.record() == true else { throw VoiceServiceError.recorderUnavailable }
    currentMeta = (householdID, listID, userID)
    stateSubject.value = VoiceSessionState(phase: .recording(startedAt: Date()), lastTranscript: nil)
  }

  func stopRecording() async throws {
    guard let recorder else { throw VoiceServiceError.recorderUnavailable }
    recorder.stop()
    self.recorder = nil

    guard let currentMeta else { throw VoiceServiceError.recorderUnavailable }
    stateSubject.value = VoiceSessionState(phase: .uploading, lastTranscript: nil)

    let fileURL = recorder.url
    let data = try Data(contentsOf: fileURL)
    let audioHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

    let timestamp = ISO8601DateFormatter().string(from: Date())
    let nonce = UUID().uuidString

    let fields: [String: String] = [
      "household_id": currentMeta.household.uuidString,
      "list_id": currentMeta.list.uuidString,
      "user_id": currentMeta.user.uuidString,
      "timestamp": timestamp,
      "nonce": nonce
    ]
    let secretData = Data(configuration.hmacSharedSecret.utf8)
    let signature = signer.sign(fields: fields, audioSHA256: audioHash, secret: secretData)

    var bodyFields = fields
    bodyFields["signature"] = signature
    bodyFields["audio_sha256"] = audioHash

    let boundary = "Boundary-\(UUID().uuidString)"
    var request = URLRequest(url: configuration.n8nWebhookURL)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = try createMultipartBody(fields: bodyFields, fileURL: fileURL, fileData: data, boundary: boundary)

    let (responseData, response) = try await urlSession.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
      stateSubject.value = VoiceSessionState(phase: .failure(errorMessage: "Upload fehlgeschlagen"), lastTranscript: nil)
      throw VoiceServiceError.uploadFailed
    }

    let payload = try JSONDecoder().decode(N8NResponse.self, from: responseData)
    switch payload.status {
    case "ok":
      stateSubject.value = VoiceSessionState(phase: .success(transcript: payload.transcript ?? ""), lastTranscript: payload.transcript)
    default:
      let message = payload.message ?? "Unbekannter Fehler"
      stateSubject.value = VoiceSessionState(phase: .failure(errorMessage: message), lastTranscript: payload.transcript)
      throw VoiceServiceError.invalidResponse
    }
  }

  func cancelRecording() {
    recorder?.stop()
    recorder = nil
    currentMeta = nil
    stateSubject.value = VoiceSessionState(phase: .idle, lastTranscript: stateSubject.value.lastTranscript)
  }

  private func createMultipartBody(fields: [String: String], fileURL: URL, fileData: Data, boundary: String) throws -> Data {
    var body = Data()
    for (key, value) in fields {
      body.appendString("--\(boundary)\r\n")
      body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
      body.appendString("\(value)\r\n")
    }

    body.appendString("--\(boundary)\r\n")
    body.appendString("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
    body.appendString("Content-Type: audio/m4a\r\n\r\n")
    body.append(fileData)
    body.appendString("\r\n")
    body.appendString("--\(boundary)--\r\n")
    return body
  }

  func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    stateSubject.value = VoiceSessionState(phase: .failure(errorMessage: error?.localizedDescription ?? "Aufnahmefehler"), lastTranscript: nil)
  }
}

private struct N8NResponse: Decodable {
  let status: String
  let transcript: String?
  let message: String?
  let items: [N8NItem]?
}

private struct N8NItem: Decodable {
  let name: String
  let quantityText: String?
  let unit: String?

  enum CodingKeys: String, CodingKey {
    case name
    case quantityText = "quantity_text"
    case unit
  }
}

private extension Data {
  mutating func appendString(_ string: String) {
    if let data = string.data(using: .utf8) {
      append(data)
    }
  }
}
