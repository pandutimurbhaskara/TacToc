import AppKit
import ApplicationServices
import Carbon
import Foundation
import IOKit.hid

enum InputMonitoringStatus: String {
    case granted
    case denied
    case unknown

    var title: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Not granted"
        case .unknown: return "Not determined"
        }
    }
}

final class PermissionService {
    static func inputMonitoringStatus() -> InputMonitoringStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .unknown
        }
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func accessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func secureInputActive() -> Bool {
        IsSecureEventInputEnabled()
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
