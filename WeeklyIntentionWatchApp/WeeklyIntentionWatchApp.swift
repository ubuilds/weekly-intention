//
//  WeeklyIntentionWatchApp.swift
//  WeeklyIntentionWatch Watch App
//
//  Created by Uwe Bury on 13.03.26.
//

import SwiftUI
import WidgetKit

@main
struct WeeklyIntentionWatchApp: App {
    init() {
        WatchConnectivityReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

struct WatchContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var intention: String = ""

    var body: some View {
        VStack(spacing: 8) {
            if intention.isEmpty {
                Image(systemName: "text.quote")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Weekly Intention")
                    .font(.headline)
                Text("Open Weekly Intention on iPhone to sync.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("This week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(intention)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear {
            refresh()
            WatchConnectivityReceiver.shared.requestIntentionFromPhone()
            // Belt-and-suspenders: kick the widget directly from the app process too,
            // not just from the WC receiver. Sometimes one path lands when the other doesn't.
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refresh()
                WatchConnectivityReceiver.shared.requestIntentionFromPhone()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchIntentionUpdated)) { _ in
            refresh()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func refresh() {
        intention = WatchConnectivityReceiver.readIntentionText()
    }
}
