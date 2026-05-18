import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkStatus {
    private(set) var isOnline: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkStatus.Monitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = (path.status == .satisfied)
            guard let self else { return }
            Task { @MainActor in
                self.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
