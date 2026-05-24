import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WatchIntentionEntry: TimelineEntry {
    let date: Date
    let text: String
    let weekStart: Date
}

// MARK: - Timeline Provider

struct WatchIntentionProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchIntentionEntry {
        WatchIntentionEntry(
            date: Date(),
            text: "Focus on what matters.",
            weekStart: WidgetSharedStore.currentISOWeekStart()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchIntentionEntry) -> Void) {
        let snap = WidgetSharedStore.read()
        completion(WatchIntentionEntry(date: Date(), text: snap.text, weekStart: snap.weekStart))
    }

    /// Two-entry timeline: current snapshot, then an empty rollover entry pinned
    /// to next Monday 00:00. Matches the iOS widget's behavior — see
    /// `WeeklyIntentionWidget.swift` for the full rationale.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchIntentionEntry>) -> Void) {
        let now = Date()
        let snap = WidgetSharedStore.read()

        let currentWeek = WidgetSharedStore.currentISOWeekStart(now: now)
        let snapshotIsForCurrentWeek = sharedCalendar.isDate(
            snap.weekStart,
            inSameDayAs: currentWeek
        )

        let currentEntry: WatchIntentionEntry
        if snapshotIsForCurrentWeek {
            currentEntry = WatchIntentionEntry(date: now, text: snap.text, weekStart: snap.weekStart)
        } else {
            currentEntry = WatchIntentionEntry(date: now, text: "", weekStart: currentWeek)
        }

        let nextWeekStart = WidgetSharedStore.startOfNextWeek(after: now)
        let rolloverEntry = WatchIntentionEntry(date: nextWeekStart, text: "", weekStart: nextWeekStart)

        let refreshAfter = sharedCalendar.date(byAdding: .minute, value: 5, to: nextWeekStart)
            ?? nextWeekStart.addingTimeInterval(300)

        completion(Timeline(entries: [currentEntry, rolloverEntry], policy: .after(refreshAfter)))
    }
}

// MARK: - Widget Views

/// Rectangular view for the Smart Stack (primary use case).
private struct RectangularView: View {
    let entry: WatchIntentionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(weekRangeText(for: entry.weekStart))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .widgetAccentable()

            if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Open on iPhone")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.text)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Circular view for watch face complications.
private struct CircularView: View {
    let entry: WatchIntentionEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Image(systemName: "text.quote")
                    .font(.title3)
            } else {
                Text(entry.text)
                    .font(.caption2)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
        }
    }
}

/// Inline view — single line of text for certain watch face slots.
private struct InlineView: View {
    let entry: WatchIntentionEntry

    var body: some View {
        if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("Open on iPhone")
        } else {
            Text(entry.text)
        }
    }
}

// MARK: - Widget View Router

struct WatchIntentionWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchIntentionEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        default:
            RectangularView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct WeeklyIntentionWatchWidget: Widget {
    let kind = "WeeklyIntentionWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchIntentionProvider()) { entry in
            WatchIntentionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weekly Intention")
        .description("Shows your current week's intention.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
