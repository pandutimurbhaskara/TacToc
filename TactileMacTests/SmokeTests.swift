import XCTest
@testable import TactileMac

final class SmokeTests: XCTestCase {
    func testSettingsDefaultsMatchProductBrief() {
        let settings = AppSettings()
        XCTAssertTrue(settings.keyboardEnabled)
        XCTAssertTrue(settings.trackpadEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        XCTAssertEqual(settings.keyboardPackID, "thock")
        XCTAssertEqual(settings.keyboardVolume, 0.65, accuracy: 0.0001)
    }
}
