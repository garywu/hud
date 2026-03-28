import Foundation
import Observation

extension Notification.Name {
    static let NotchyHidePanel = Notification.Name("NotchyHidePanel")
    static let NotchyExpandPanel = Notification.Name("NotchyExpandPanel")
    static let NotchyNotchStatusChanged = Notification.Name("NotchyNotchStatusChanged")
}

@Observable
class SessionStore {
    static let shared = SessionStore()
    let statusWatcher = StatusWatcher.shared
    let janeClient = JaneClient.shared

    var isPinned: Bool = {
        if UserDefaults.standard.object(forKey: "isPinned") == nil { return true }
        return UserDefaults.standard.bool(forKey: "isPinned")
    }() {
        didSet {
            UserDefaults.standard.set(isPinned, forKey: "isPinned")
        }
    }
    var isWindowFocused = true
    var isShowingDialog = false

    var notchDisplayState: NotchDisplayState {
        switch statusWatcher.currentStatus.status {
        case "sos": return .sos
        case "red": return .urgent
        case "yellow": return .attention
        case "green": return .nominal
        default: return .offline
        }
    }
}
