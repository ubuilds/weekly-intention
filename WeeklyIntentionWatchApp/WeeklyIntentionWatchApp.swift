//
//  WeeklyIntentionWatchApp.swift
//  WeeklyIntentionWatch Watch App
//
//  Created by Uwe Bury on 13.03.26.
//

import SwiftUI

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
                Text("Set your intention on iPhone — it appears here and in the Smart Stack.")
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
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        intention = WatchConnectivityReceiver.readIntentionText()
    }
}
