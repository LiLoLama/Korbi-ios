import Foundation
import CryptoKit

protocol HMACSigning {
  func sign(fields: [String: String], audioSHA256: String, secret: Data) -> String
}

struct HMACSigner: HMACSigning {
  static let shared = HMACSigner()

  func sign(fields: [String: String], audioSHA256: String, secret: Data) -> String {
    var canonical = fields.sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: "\n")
    canonical.append("\naudio_sha256=\(audioSHA256)")
    let key = SymmetricKey(data: secret)
    let signature = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
    return signature.map { String(format: "%02x", $0) }.joined()
  }
}
