import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

/// Sends the current week's intention to the paired Apple Watch via WatchConnectivity.
/// Uses `updateApplicationContext` so the latest data is always available when the watch wakes.
final class PhoneToWatchConnector: NSObject, WCSessionDelegate {
    static let shared = PhoneToWatchConnector()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendIntention(weekStartISO: String, text: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let context: [String: Any] = [
            "widget.weekStartISO": weekStartISO,
            "widget.intentionText": text,
            "widget.updatedAtISO": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            try session.updateApplicationContext(context)
        } catch {
            print("WCSession updateApplicationContext failed:", error)
        }
    }

    // MARK: - WCSessionDelegate (required on iOS)

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for multi-watch support
        session.activate()
    }
}
#endif
