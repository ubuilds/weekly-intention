import Foundation
import Observation

@MainActor
@Observable
final class SyncStatus {
    enum State: Equatable {
        case none
        case offline
        case syncing
    }

    private(set) var state: State = .none

    func handleNetworkChange(isOnline: Bool) {
        if !isOnline {
            state = .offline
            return
        }

        // Came back online
        if state == .offline {
            state = .syncing

            // We don’t “know” when CloudKit is fully done; we show a brief syncing hint.
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s
                if self.state == .syncing {
                    self.state = .none
                }
            }
        } else {
            // Online and not recovering from offline -> no indicator
            state = .none
        }
    }

    var labelText: String? {
        switch state {
        case .none: return nil
        case .offline: return "Offline"
        case .syncing: return "Syncing…"
        }
    }
}
