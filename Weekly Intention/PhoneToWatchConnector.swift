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

    /// Watch asks for the current intention on launch (see WatchConnectivityReceiver.requestIntentionFromPhone).
    /// Reply with whatever the iOS App Group cache currently holds; the watch persists it
    /// into its own App Group and reloads the widget.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["request"] as? String == "currentIntention" else {
            replyHandler([:])
            return
        }

        let snapshot = WidgetSharedStore.read()
        var reply: [String: Any] = [
            "widget.weekStartISO": WidgetSharedStore.isoDateString(snapshot.weekStart),
            "widget.intentionText": snapshot.text
        ]
        if let updatedAt = snapshot.updatedAt {
            reply["widget.updatedAtISO"] = WidgetSharedStore.isoDateString(updatedAt)
        }
        replyHandler(reply)
    }
}
#endif
