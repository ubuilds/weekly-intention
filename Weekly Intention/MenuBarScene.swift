import SwiftUI
import SwiftData

#if os(macOS)
import AppKit

/// macOS-only views for the menu bar item.
///
/// The menu bar is the macOS equivalent of the iOS Lock Screen widget — a
/// surface that's *quietly visible on every screen* (per VISION.md) without
/// pulling the user into the app. Reads the same SwiftData store the main
/// window uses, so the menu bar reflects edits from any device the moment
/// CloudKit syncs.
///
/// Composition: `MenuBarExtra` in `Weekly_IntentionApp` uses `MenuBarLabel`
/// for the menu-bar chrome and `MenuBarContent` for the click-through popover.

// MARK: - Label

/// The compact view shown in the menu bar itself — icon plus current
/// intention text, truncated to fit. macOS gives menu bar items as much
/// width as they need within reason; truncation kicks in for long intentions.
struct MenuBarLabel: View {
    @Query private var intentions: [WeeklyIntention]

    var body: some View {
        let text = currentIntentionText(in: intentions)
        HStack(spacing: 4) {
            Image(systemName: "text.quote")
            if !text.isEmpty {
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

// MARK: - Popover content

/// The window-style popover shown when the menu bar item is clicked.
/// Read-only by design — editing happens in the main window. The popover
/// surfaces the full intention text plus a button to bring the main window
/// forward (creates it if no window is currently open).
struct MenuBarContent: View {
    @Query private var intentions: [WeeklyIntention]
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let text = currentIntentionText(in: intentions)
        let weekStart = WidgetSharedStore.currentISOWeekStart()

        VStack(alignment: .leading, spacing: 12) {
            Text(weekRangeText(for: weekStart))
                .font(.caption)
                .foregroundStyle(.secondary)

            if text.isEmpty {
                Text("Set your weekly intention")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            Button {
                // Bring the app forward and open (or focus) the main window.
                // `openWindow(id:)` focuses an existing window if one is open,
                // creates a new instance otherwise. The explicit
                // `NSApplication.shared.activate()` covers the case where the
                // app is in the background but a window is already visible —
                // without it the click sometimes only flashes the popover.
                NSApplication.shared.activate()
                openWindow(id: WeeklyIntentionApp.mainWindowID)
            } label: {
                Label("Open Weekly Intention", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(width: 280)
    }
}

// MARK: - Shared lookup

/// Returns the current week's intention text, or empty if none is set.
/// Prefers the most-recently-updated row among matches, mirroring the
/// dedupe pattern used elsewhere in the app — CloudKit duplicates for the
/// same `weekStart` should resolve to "last write wins" here too.
fileprivate func currentIntentionText(in items: [WeeklyIntention]) -> String {
    let currentWeek = WidgetSharedStore.currentISOWeekStart()
    let matches = items.filter {
        sharedCalendar.isDate($0.weekStart, inSameDayAs: currentWeek)
    }
    guard let first = matches.first else { return "" }
    let best = matches.reduce(first) { acc, candidate in
        candidate.updatedAt > acc.updatedAt ? candidate : acc
    }
    return best.text.trimmingCharacters(in: .whitespacesAndNewlines)
}

#endif
