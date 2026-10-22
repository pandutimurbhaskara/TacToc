import Foundation
import IOKit

struct TrackpadCapability: Equatable {
    var detected = false
    var forceTouchReported = false
    var actuationReported = false
    var embedded = false
    var productName: String?

    var summary: String {
        if !detected { return "No multitouch trackpad detected through IORegistry." }
        if actuationReported {
            return embedded ? "Built-in Force Touch trackpad reports actuation support." : "Trackpad reports actuation support."
        }
        if forceTouchReported {
            return "Trackpad reports Force Touch support; public haptics have no capability query."
        }
        return "Trackpad detected; haptic capability is not queryable through public APIs."
    }
}

enum CapabilityService {
    static func trackpad() -> TrackpadCapability {
        let classes = ["AppleMultitouchTrackpadHIDEventDriver", "AppleMultitouchDevice", "AppleMultitouchTrackpad"]
        var result = TrackpadCapability()
        for className in classes {
            let services = matchingServices(className)
            if !services.isEmpty { result.detected = true }
            for service in services {
                defer { IOObjectRelease(service) }
                if result.productName == nil {
                    result.productName = (property(service, "Product") as? String)
                }
                if boolProperty(service, "ActuationSupported") { result.actuationReported = true }
                if boolProperty(service, "ForceSupported") { result.forceTouchReported = true }
                if boolProperty(service, "TrackpadEmbedded") || boolProperty(service, "MT Built-In") { result.embedded = true }
            }
        }
        return result
    }

    private static func matchingServices(_ className: String) -> [io_service_t] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var services: [io_service_t] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            services.append(service)
        }
        return services
    }

    private static func property(_ service: io_service_t, _ key: String) -> AnyObject? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private static func boolProperty(_ service: io_service_t, _ key: String) -> Bool {
        (property(service, key) as? NSNumber)?.boolValue ?? false
    }
}
