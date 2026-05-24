import SwiftUI
import SwiftData

@main
struct WeeklyIntentionApp: App {
    /// Window identifier used by `openWindow(id:)` from the macOS menu bar
    /// popover, so clicking "Open Weekly Intention" focuses the existing
    /// window (or creates it if no window is open).
    static let mainWindowID = "main"

    @Environment(\.scenePhase) private var scenePhase

    @State private var appState = AppState()
    @State private var networkStatus = NetworkStatus()
    @State private var syncStatus = SyncStatus()
    @State private var iCloudAccountStatus = CloudKitAccountStatus()
    private let modelContainer: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .private("iCloud.com.uwebury.weeklyintention")
            )
            self.modelContainer = try ModelContainer(
                for: WeeklyIntention.self,
                configurations: config
            )
            print("✅ SwiftData: CloudKit sync enabled (private DB)")
        } catch {
            fatalError("❌ SwiftData: Failed to create CloudKit-backed ModelContainer. Error: \(error)")
        }

        // Activate WatchConnectivity so we can push intention updates to the watch.
        #if canImport(WatchConnectivity)
        PhoneToWatchConnector.shared.activate()
        #endif
    }

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView()
                .environment(appState)
                .environment(networkStatus)
                .environment(syncStatus)
                .environment(iCloudAccountStatus)
                .onAppear {
                    syncStatus.handleNetworkChange(isOnline: networkStatus.isOnline)
                }
                .onChange(of: networkStatus.isOnline) { _, newValue in
                    syncStatus.handleNetworkChange(isOnline: newValue)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncStatus.handleNetworkChange(isOnline: networkStatus.isOnline)
                        iCloudAccountStatus.refresh()

                        // Mirror current-week intention into widget cache after potential CloudKit sync.
                        // Week math goes through the shared ISO (Monday-based) calendar — never Calendar.current.
                        let weekStart = WidgetSharedStore.currentISOWeekStart()
                        let weekEnd = sharedCalendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

                        // `mainContext` is @MainActor — annotate the Task so we don't
                        // accidentally cross actors under Swift 6 strict concurrency.
                        Task { @MainActor in
                            do {
                                let descriptor = FetchDescriptor<WeeklyIntention>(
                                    predicate: #Predicate { $0.weekStart >= weekStart && $0.weekStart < weekEnd }
                                )
                                if let current = try modelContainer.mainContext.fetch(descriptor).first {
                                    WidgetSharedStore.writeCurrentWeekIntention(
                                        weekStart: current.weekStart,
                                        text: current.text
                                    )

                                    // Also push to Apple Watch
                                    #if canImport(WatchConnectivity)
                                    PhoneToWatchConnector.shared.sendIntention(
                                        weekStartISO: WidgetSharedStore.isoDateString(current.weekStart),
                                        text: current.text
                                    )
                                    #endif
                                }
                            } catch {
                                print("Widget mirror fetch failed:", error)
                            }
                        }
                    }
                }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .commands {
            CommandMenu("Edit") {
                Button("Search Intentions…") {
                    appState.presentRecall(focusSearch: true)
                }
                .disabled(syncStatus.state == .syncing)
                .keyboardShortcut("f", modifiers: [.command])
            }
        }
        #endif

        // macOS menu bar item — the Mac equivalent of the iOS Lock Screen
        // widget. The same ModelContainer is attached so @Query inside the
        // menu bar views observes the same SwiftData store the main window
        // uses, and updates reactively as edits + CloudKit syncs arrive.
        #if os(macOS)
        MenuBarExtra {
            MenuBarContent()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
        #endif
    }
}
