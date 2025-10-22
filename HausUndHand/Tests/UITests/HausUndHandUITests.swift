import XCTest

final class HausUndHandUITests: XCTestCase {
  func testExampleLaunch() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
  }
}
