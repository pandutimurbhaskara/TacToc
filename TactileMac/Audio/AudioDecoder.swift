import AVFoundation
import Foundation

struct DecodedAudio {
    let url: URL
    let sampleRate: Double
    let channels: Int
    let frameCount: Int
    /// Interleaved stereo Float32 at the source sample rate.
    let samples: [Float]

    var duration: TimeInterval { sampleRate > 0 ? Double(frameCount) / sampleRate : 0 }
}

struct AudioProbeResult {
    let url: URL
    let sampleRate: Double
    let channels: Int
    let frameCount: Int
    let duration: TimeInterval
    let fileSize: Int64
}

enum AudioDecodeError: LocalizedError {
    case unreadable(URL, String)
    case empty(URL)
    case tooLong(URL, Double)
    case noFloatData(URL)
    case allocationFailed(URL)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url, let message):
            return "\(url.lastPathComponent) could not be decoded: \(message)"
        case .empty(let url):
            return "\(url.lastPathComponent) contains no audio frames."
        case .tooLong(let url, let seconds):
            return "\(url.lastPathComponent) is longer than the \(Int(seconds)) second limit."
        case .noFloatData(let url):
            return "\(url.lastPathComponent) is not decodable to Float32 PCM."
        case .allocationFailed(let url):
            return "Not enough memory to prepare \(url.lastPathComponent)."
        }
    }
}

enum AudioDecoder {
    static let maximumDuration: TimeInterval = 600

    static func probe(url: URL, maximumDuration: TimeInterval = maximumDuration) throws -> AudioProbeResult {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioDecodeError.unreadable(url, error.localizedDescription)
        }
        let format = file.processingFormat
        guard format.sampleRate > 0, format.channelCount > 0, file.length > 0 else {
            throw AudioDecodeError.empty(url)
        }
        let duration = Double(file.length) / format.sampleRate
        guard duration <= maximumDuration else {
            throw AudioDecodeError.tooLong(url, maximumDuration)
        }
        // Opening is not enough: some containers expose a header but fail while
        // decoding. Read a small block to prove the decoder really works.
        let frames = AVAudioFrameCount(min(file.length, 2048))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw AudioDecodeError.allocationFailed(url)
        }
        do {
            try file.read(into: buffer, frameCount: frames)
        } catch {
            throw AudioDecodeError.unreadable(url, error.localizedDescription)
        }
        guard buffer.frameLength > 0, buffer.floatChannelData != nil else {
            throw AudioDecodeError.noFloatData(url)
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return AudioProbeResult(
            url: url,
            sampleRate: format.sampleRate,
            channels: Int(format.channelCount),
            frameCount: Int(file.length),
            duration: duration,
            fileSize: size
        )
    }

    static func decode(url: URL, maximumDuration: TimeInterval = maximumDuration) throws -> DecodedAudio {
        let probe = try probe(url: url, maximumDuration: maximumDuration)
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioDecodeError.unreadable(url, error.localizedDescription)
        }
        let format = file.processingFormat
        guard file.length > 0, file.length <= UInt32.max else { throw AudioDecodeError.empty(url) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw AudioDecodeError.allocationFailed(url)
        }
        do {
            try file.read(into: buffer)
        } catch {
            throw AudioDecodeError.unreadable(url, error.localizedDescription)
        }
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else {
            throw AudioDecodeError.noFloatData(url)
        }

        let frames = Int(buffer.frameLength)
        let inputChannels = Int(format.channelCount)
        var interleaved = [Float](repeating: 0, count: frames * 2)
        interleaved.withUnsafeMutableBufferPointer { output in
            guard let out = output.baseAddress else { return }
            if inputChannels == 1 {
                let mono = channels[0]
                for frame in 0..<frames {
                    let value = mono[frame]
                    out[frame * 2] = value
                    out[frame * 2 + 1] = value
                }
            } else {
                let left = channels[0]
                let right = channels[1]
                for frame in 0..<frames {
                    out[frame * 2] = left[frame]
                    out[frame * 2 + 1] = right[frame]
                }
            }
        }
        return DecodedAudio(
            url: url,
            sampleRate: probe.sampleRate,
            channels: 2,
            frameCount: frames,
            samples: interleaved
        )
    }
}

final class AudioDecodeCache {
    private var decoded: [String: DecodedAudio] = [:]
    private var probes: [String: AudioProbeResult] = [:]
    private let lock = NSLock()

    func probe(_ url: URL) throws -> AudioProbeResult {
        lock.lock()
        if let cached = probes[url.path] { lock.unlock(); return cached }
        lock.unlock()
        let result = try AudioDecoder.probe(url: url)
        lock.lock(); probes[url.path] = result; lock.unlock()
        return result
    }

    func decode(_ url: URL) throws -> DecodedAudio {
        lock.lock()
        if let cached = decoded[url.path] { lock.unlock(); return cached }
        lock.unlock()
        let result = try AudioDecoder.decode(url: url)
        lock.lock(); decoded[url.path] = result; lock.unlock()
        return result
    }

    func removeAll() {
        lock.lock(); decoded.removeAll(); probes.removeAll(); lock.unlock()
    }
}
