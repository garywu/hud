import Foundation
import Observation

// MARK: - Stub: JaneClient
// Placeholder for the Jane real-time data client (not yet implemented).

@Observable
class JaneClient {
    static let shared = JaneClient()

    var isConnected: Bool = false
    var janeContext: String? = nil
    var criticalCount: Int = 0
    var warningCount: Int = 0
    var unresolvedCount: Int = 0
    var latestAutonomyScore: Double? = nil
    var lastSessionSummary: String? = nil

    func startPolling() {
        // Stub — will connect to Jane API when implemented
    }
}

// MARK: - Stub: ContextGaugePlugin

class ContextGaugePlugin {
    static let shared = ContextGaugePlugin()

    func startWatching() {
        // Stub — will monitor context window usage when implemented
    }
}
