import XCTest
@testable import TactileMac

final class KeyMappingTests: XCTestCase {
    func testKnownMacKeyCodes() {
        XCTAssertEqual(KeyCodeMap.descriptor(for: 0)?.w3cName, "KeyA")
        XCTAssertEqual(KeyCodeMap.descriptor(for: 49)?.w3cName, "Space")
        XCTAssertEqual(KeyCodeMap.descriptor(for: 36)?.w3cName, "Enter")
        XCTAssertEqual(KeyCodeMap.descriptor(for: 51)?.w3cName, "Backspace")
        XCTAssertEqual(KeyCodeMap.descriptor(for: 63)?.w3cName, "Fn")
        XCTAssertEqual(KeyCodeMap.descriptor(for: 126)?.w3cName, "ArrowUp")
        XCTAssertNil(KeyCodeMap.descriptor(for: 9999))
    }

    func testEventResolutionOrderIsExactCategoryDefault() {
        let descriptor = try! XCTUnwrap(KeyCodeMap.descriptor(for: 49))
        XCTAssertEqual(descriptor.downEvents, ["key.down.Space", "key.down.space", "key.down.default"])
        XCTAssertEqual(descriptor.upEvents, ["key.up.Space", "key.up.space", "key.up.default"])
    }

    func testLegacyKeyCodes() {
        XCTAssertEqual(LegacyKeyMap.w3cName(forLegacyCode: "30"), "KeyA")
        XCTAssertEqual(LegacyKeyMap.w3cName(forLegacyCode: "14"), "Backspace")
        XCTAssertEqual(LegacyKeyMap.w3cName(forLegacyCode: "57"), "Space")
        XCTAssertEqual(LegacyKeyMap.w3cName(forLegacyCode: "57424"), "ArrowDown")
        XCTAssertEqual(LegacyKeyMap.w3cName(forLegacyCode: "3639"), "F13")
        XCTAssertEqual(LegacyKeyMap.w3cName(forLegacyCode: "KeyA"), "KeyA")
        XCTAssertNil(LegacyKeyMap.w3cName(forLegacyCode: "not-a-key"))
    }

    func testLegacyMouseCodesIncludingZeroPaddedRelease() {
        let left = LegacyKeyMap.mouseButton(forLegacyCode: "1")
        XCTAssertEqual(left?.0, .left)
        XCTAssertEqual(left?.1, false)
        let leftUp = LegacyKeyMap.mouseButton(forLegacyCode: "01")
        XCTAssertEqual(leftUp?.0, .left)
        XCTAssertEqual(leftUp?.1, true)
        XCTAssertNil(LegacyKeyMap.mouseButton(forLegacyCode: "99"))
    }

    func testUnsupportedEventKeysAreRejected() {
        XCTAssertTrue(PackEvent.isSupported("key.down.default"))
        XCTAssertTrue(PackEvent.isSupported("key.down.KeyA"))
        XCTAssertTrue(PackEvent.isSupported("key.up.modifier"))
        XCTAssertTrue(PackEvent.isSupported("trackpad.click.left"))
        XCTAssertTrue(PackEvent.isSupported("trackpad.scroll.down"))
        XCTAssertFalse(PackEvent.isSupported("key.down.NotAKey"))
        XCTAssertFalse(PackEvent.isSupported("trackpad.gesture.pinch"))
    }
}
