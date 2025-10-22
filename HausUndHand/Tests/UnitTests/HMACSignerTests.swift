import XCTest
@testable import HausUndHand

final class HMACSignerTests: XCTestCase {
  func testSignatureDeterministic() throws {
    let signer = HMACSigner.shared
    let fields = [
      "household_id": UUID(uuidString: "00000000-0000-0000-0000-000000000001")!.uuidString,
      "list_id": UUID(uuidString: "00000000-0000-0000-0000-000000000002")!.uuidString,
      "user_id": UUID(uuidString: "00000000-0000-0000-0000-000000000003")!.uuidString,
      "timestamp": "2024-01-01T12:00:00Z",
      "nonce": "11111111-1111-1111-1111-111111111111"
    ]
    let hash = String(repeating: "a", count: 64)
    let secret = Data("secret".utf8)

    let signature = signer.sign(fields: fields, audioSHA256: hash, secret: secret)
    XCTAssertEqual(signature.count, 64)
    XCTAssertEqual(signature, signer.sign(fields: fields, audioSHA256: hash, secret: secret))
  }
}
