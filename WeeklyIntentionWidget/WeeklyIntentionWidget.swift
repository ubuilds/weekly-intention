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

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyIntentionEntry>) -> Void) {
        let snap = WidgetSharedStore.read()

        let entry = WeeklyIntentionEntry(
            date: Date(),
            weekStart: snap.weekStart,
            text: snap.text,
            updatedAt: snap.updatedAt
        )

        // Refresh periodically (and also on reloadAllTimelines from the app)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
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
