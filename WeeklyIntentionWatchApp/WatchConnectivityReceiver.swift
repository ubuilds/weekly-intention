import Foundation
import WatchConnectivity
import WidgetKit

extension Notification.Name {
    /// Posted whenever the watch's App Group cache is updated from the phone — via
    /// either an applicationContext push or a sendMessage reply. Observed by the watch
    /// app's main view so the UI re-reads the cache immediately.
    static let watchIntentionUpdated = Notification.Name("watchIntentionUpdated")
}

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

    /// Ask the iPhone for its current intention and persist the reply.
    /// Used on watch app launch to self-heal the App Group cache — otherwise a freshly
    /// installed watch app shows "Set your intention" until the user opens the iPhone app.
    /// Silent on failure: if the phone isn't reachable (terminated, out of range), we
    /// keep showing whatever's cached and the phone's normal scenePhase push will catch up.
    func requestIntentionFromPhone() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }

        session.sendMessage(["request": "currentIntention"], replyHandler: { [weak self] reply in
            self?.persistAndReload(reply)
        }, errorHandler: { error in
            print("WCSession sendMessage failed:", error.localizedDescription)
        })
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
        // `synchronize()` is documented as a no-op on modern Cocoa, but on watchOS
        // it still appears to prod cfprefsd into cross-process notification a bit
        // sooner — keep it. Cheap insurance for the widget extension picking up
        // the new values on its next read.
        defaults.synchronize()

        // Reload ALL timelines (not just our kind) — slightly stronger hint to
        // watchOS, which treats reloadTimelines as advisory. Smart Stack in
        // particular ignores per-kind hints more aggressively than per-bundle.
        WidgetCenter.shared.reloadAllTimelines()

        // Tell the watch app UI to re-read the cache.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .watchIntentionUpdated, object: nil)
        }
    }
}
