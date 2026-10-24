import XCTest
@testable import TactileMac

final class HapticMaterialTests: XCTestCase {
    func testDefaultsEnableMaterialMovementAndScrollHaptics() {
        let settings = AppSettings()
        XCTAssertTrue(settings.enhancedHaptics)
        XCTAssertTrue(settings.hapticOnPointerMovement)
        XCTAssertTrue(settings.hapticOnScroll)
        XCTAssertEqual(settings.hapticMaterial, .felt)
        XCTAssertEqual(settings.hapticIntensity, 0.6, accuracy: 0.0001)
    }

    func testMaterialStrengthMapping() {
        XCTAssertEqual(HapticMaterialName.fineGrit.actuationID(for: 0.6), 3)
        XCTAssertEqual(HapticMaterialName.felt.actuationID(for: 0.6), 4)
        XCTAssertEqual(HapticMaterialName.pebbled.actuationID(for: 0.6), 6)
        XCTAssertEqual(HapticMaterialName.lineGrid.actuationID(for: 1.0), 6)
        XCTAssertEqual(HapticMaterialName.softGrid.publicPattern(for: 0.2), .alignment)
        XCTAssertEqual(HapticMaterialName.softGrid.publicPattern(for: 0.5), .generic)
        XCTAssertEqual(HapticMaterialName.softGrid.publicPattern(for: 0.9), .levelChange)
    }

    func testMaterialsHaveDistinctRhythms() {
        XCTAssertNotEqual(HapticMaterialName.felt.spacing, HapticMaterialName.pebbled.spacing)
        XCTAssertNotEqual(HapticMaterialName.fineGrit.minimumInterval, HapticMaterialName.lineGrid.minimumInterval)
        XCTAssertEqual(HapticMaterialName.softGrid.jitter, 0)
        XCTAssertGreaterThan(HapticMaterialName.pebbled.jitter, HapticMaterialName.fineGrit.jitter)
    }

    func testIntensityIsClampedWhenSettingsAreSaved() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let paths = try makePaths(in: temp)
        let store = SettingsStore(paths: paths)
        var settings = AppSettings()
        settings.hapticIntensity = 9
        try store.save(settings)
        XCTAssertEqual(store.load().settings.hapticIntensity, 1, accuracy: 0.0001)
    }
}
