import Foundation
import Observation
import CloudKit

/// Tracks whether the user's iCloud account is currently usable.
///
/// The vision says the app should be *honest* — what the user sees should reflect
/// what is true. Without this, signing out of iCloud (or running out of storage)
/// silently fails: SwiftData keeps writing locally, but nothing syncs to other
/// devices and the user has no idea. This observable surfaces that state so
/// `ContentView` can show a pill explaining what's going on.
@MainActor
@Observable
final class CloudKitAccountStatus {
    enum State: Equatable {
        /// Account state hasn't been determined yet — render nothing.
        case unknown
        /// `.available` — sync is expected to work.
        case available
        /// `.noAccount` / `.restricted` / `.couldNotDetermine` / `.temporarilyUnavailable`.
        case unavailable(reason: String)
    }

    private(set) var state: State = .unknown

    private let container: CKContainer

    /// Held to keep the closure alive for the lifetime of this object.
    /// `@ObservationIgnored` keeps it out of `@Observable`'s tracking machinery.
    /// We deliberately don't clean it up in `deinit` — this object is owned by
    /// the App struct and lives for the entire process lifetime, so `deinit`
    /// only fires at termination when the observer is being torn down anyway.
    /// Avoiding `deinit` access also sidesteps the MainActor-isolation friction
    /// (deinit is nonisolated; stored vars on a MainActor class cannot be marked
    /// `nonisolated`).
    @ObservationIgnored
    private var observer: NSObjectProtocol?

    init(containerIdentifier: String = "iCloud.com.uwebury.weeklyintention") {
        self.container = CKContainer(identifier: containerIdentifier)
        startObserving()
        refresh()
    }

    func refresh() {
        container.accountStatus { [weak self] status, error in
            // Bind to a local let so the Task closure captures a let-self
            // rather than the outer closure's var-self (Swift 6 strict).
            let capturedSelf = self
            Task { @MainActor in
                capturedSelf?.apply(status: status, error: error)
            }
        }
    }

    /// Short pill label, or `nil` when nothing needs to be shown.
    var labelText: String? {
        switch state {
        case .unknown, .available:
            return nil
        case .unavailable:
            return "iCloud unavailable"
        }
    }

    /// Longer accessibility / tooltip explanation.
    var accessibilityDescription: String? {
        switch state {
        case .unknown, .available:
            return nil
        case .unavailable(let reason):
            return "iCloud unavailable — \(reason). Intentions are saved on this device but won't sync."
        }
    }

    // MARK: - Private

    /// Done in a post-init method so `self` is a let, not init-time var-self —
    /// avoids Swift 6 "reference to captured var 'self'" warnings.
    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let capturedSelf = self
            Task { @MainActor in
                capturedSelf?.refresh()
            }
        }
    }

    private func apply(status: CKAccountStatus, error: Error?) {
        state = Self.state(from: status, error: error)
    }

    private static func state(from status: CKAccountStatus, error: Error?) -> State {
        if let error {
            return .unavailable(reason: error.localizedDescription)
        }
        switch status {
        case .available:
            return .available
        case .noAccount:
            return .unavailable(reason: "no iCloud account signed in")
        case .restricted:
            return .unavailable(reason: "iCloud is restricted on this device")
        case .temporarilyUnavailable:
            return .unavailable(reason: "iCloud temporarily unavailable")
        case .couldNotDetermine:
            return .unavailable(reason: "iCloud status couldn't be determined")
        @unknown default:
            return .unavailable(reason: "iCloud status unknown")
        }
    }
}
