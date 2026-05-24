import WidgetKit
import SwiftUI

struct WeeklyIntentionEntry: TimelineEntry {
    let date: Date
    let weekStart: Date
    let text: String
    let updatedAt: Date?
}

struct WeeklyIntentionProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyIntentionEntry {
        WeeklyIntentionEntry(
            date: Date(),
            weekStart: WidgetSharedStore.currentISOWeekStart(),
            text: "Focus on what matters.",
            updatedAt: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyIntentionEntry) -> Void) {
        let snap = WidgetSharedStore.read()
        completion(
            WeeklyIntentionEntry(
                date: Date(),
                weekStart: snap.weekStart,
                text: snap.text,
                updatedAt: snap.updatedAt
            )
        )
    }

    /// Two-entry timeline:
    /// - now → the cached snapshot (today's intention)
    /// - next Monday 00:00 → an empty entry pinned to the new week, so the widget
    ///   transitions cleanly to "Set your weekly intention" even if the user
    ///   doesn't open the app over the weekend
    ///
    /// `WidgetSharedStore.writeCurrentWeekIntention` reloads the timeline on every
    /// save, so the empty rollover entry only ever surfaces if the user genuinely
    /// hasn't set the new week yet.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyIntentionEntry>) -> Void) {
        let now = Date()
        let snap = WidgetSharedStore.read()

        let currentWeek = WidgetSharedStore.currentISOWeekStart(now: now)
        let snapshotIsForCurrentWeek = sharedCalendar.isDate(
            snap.weekStart,
            inSameDayAs: currentWeek
        )

        // First entry — current snapshot, but if it's stale (last week's text
        // still cached), treat as empty for honesty.
        let currentEntry: WeeklyIntentionEntry
        if snapshotIsForCurrentWeek {
            currentEntry = WeeklyIntentionEntry(
                date: now,
                weekStart: snap.weekStart,
                text: snap.text,
                updatedAt: snap.updatedAt
            )
        } else {
            currentEntry = WeeklyIntentionEntry(
                date: now,
                weekStart: currentWeek,
                text: "",
                updatedAt: nil
            )
        }

        // Second entry — the rollover. At next Monday 00:00 the widget
        // displays an empty entry for the new week until the user sets one.
        let nextWeekStart = WidgetSharedStore.startOfNextWeek(after: now)
        let rolloverEntry = WeeklyIntentionEntry(
            date: nextWeekStart,
            weekStart: nextWeekStart,
            text: "",
            updatedAt: nil
        )

        // Refresh again shortly after the rollover so we re-read the App Group
        // cache (the user may have set next week's intention by then).
        let refreshAfter = sharedCalendar.date(byAdding: .minute, value: 5, to: nextWeekStart)
            ?? nextWeekStart.addingTimeInterval(300)

        completion(Timeline(entries: [currentEntry, rolloverEntry], policy: .after(refreshAfter)))
    }
}

struct WeeklyIntentionWidgetView: View {
    var entry: WeeklyIntentionProvider.Entry

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weekRangeText(for: entry.weekStart))
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Set your weekly intention")
                    .font(.headline)
            } else {
                Text(entry.text)
                    .font(.headline)
                    .lineLimit(4)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    var body: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content
                .containerBackground(.fill.tertiary, for: .widget)
        } else {
            content
        }
    }

}

struct WeeklyIntentionWidget: Widget {
    let kind: String = "WeeklyIntentionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyIntentionProvider()) { entry in
            WeeklyIntentionWidgetView(entry: entry)
        }
        .configurationDisplayName("Weekly Intention")
        .description("Shows your current week’s intention.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
