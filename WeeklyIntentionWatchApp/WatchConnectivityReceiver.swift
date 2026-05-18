import Foundation
import WatchConnectivity
import WidgetKit

/// Receives the current week's intention from the paired iPhone via WatchConnectivity
/// and persists it so the watchOS widget and watch app can display it.
final class WatchConnectivityReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityReceiver()

    /// App Group shared between this watch app and the watch widget extension.
    /// App Groups are per-device, so this is the watch's own container — separate
    /// from the phone's. WatchConnectivity is what bridges phone → watch.
    private static let suiteName = "group.com.uwebury.weeklyintention"

    private static let keyWeekStartISO = "widget.weekStartISO"
    private static let keyIntentionText = "widget.intentionText"
    private static let keyUpdatedAtISO = "widget.updatedAtISO"

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// The intention text last received from the phone — for the watch app UI.
    static func readIntentionText() -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: keyIntentionText) ?? ""
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    /// Called when the iOS app sends `updateApplicationContext`.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        persistAndReload(applicationContext)
    }

    private func persistAndReload(_ context: [String: Any]) {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else { return }

        if let weekStartISO = context[Self.keyWeekStartISO] as? String {
            defaults.set(weekStartISO, forKey: Self.keyWeekStartISO)
        }
        if let text = context[Self.keyIntentionText] as? String {
            defaults.set(text, forKey: Self.keyIntentionText)
        }
        if let updatedAt = context[Self.keyUpdatedAtISO] as? String {
            defaults.set(updatedAt, forKey: Self.keyUpdatedAtISO)
        }

        // Tell WidgetKit to refresh the watchOS widget.
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyIntentionWatchWidget")
    }
}
