import XCTest
@testable import TactileMac

final class AudioDecodeTests: XCTestCase {
    func testWavProbeAndDecode() throws {
        let url = Fixtures.url("Audio/tone.wav")
        let probe = try AudioDecoder.probe(url: url)
        XCTAssertEqual(probe.sampleRate, 44_100, accuracy: 0.1)
        XCTAssertEqual(probe.channels, 2)
        XCTAssertGreaterThan(probe.frameCount, 1000)
        let audio = try AudioDecoder.decode(url: url)
        XCTAssertEqual(audio.channels, 2)
        XCTAssertEqual(audio.frameCount, probe.frameCount)
        XCTAssertEqual(audio.samples.count, audio.frameCount * 2)
        XCTAssertTrue(audio.samples.contains { abs($0) > 0.01 })
    }

    func testOggVorbisFixtureDecodesThroughAVFoundation() throws {
        let url = Fixtures.url("Audio/tone.ogg")
        let probe = try AudioDecoder.probe(url: url)
        XCTAssertEqual(probe.sampleRate, 44_100, accuracy: 0.1)
        XCTAssertEqual(probe.channels, 2)
        let audio = try AudioDecoder.decode(url: url)
        XCTAssertGreaterThan(audio.frameCount, 1000)
        XCTAssertEqual(audio.samples.count, audio.frameCount * 2)
        XCTAssertTrue(audio.samples.contains { abs($0) > 0.01 })
    }

    func testCorruptAndEmptyAudioAreRejected() throws {
        let temp = try TemporaryDirectory()
        defer { temp.remove() }
        let empty = temp.url.appendingPathComponent("empty.ogg")
        try Data().write(to: empty)
        XCTAssertThrowsError(try AudioDecoder.probe(url: empty))

        let garbage = temp.url.appendingPathComponent("garbage.ogg")
        try Data("not an audio file".utf8).write(to: garbage)
        XCTAssertThrowsError(try AudioDecoder.probe(url: garbage))
    }
}
