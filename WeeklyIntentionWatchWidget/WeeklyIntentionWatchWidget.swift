import WidgetKit
import SwiftUI

// MARK: - App Group Data Reader

/// Reads the current week's intention from the shared App Group UserDefaults.
/// Self-contained so the watchOS widget extension has no cross-target dependencies.
///
/// Mirror of `WidgetSharedStore` (on the iOS side) — both must agree on key names,
/// ISO formatter shape, and week math. Block 2 of the audit consolidates this
/// into one source of truth across all four targets.
private enum WatchSharedReader {
    static let appGroupID = "group.com.uwebury.weeklyintention"

    struct Snapshot {
        let weekStart: Date
        let text: String
    }

    static func read() -> Snapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return Snapshot(weekStart: currentISOWeekStart(), text: "")
        }
        let weekStart = parseISODate(defaults.string(forKey: "widget.weekStartISO")) ?? currentISOWeekStart()
        let text = defaults.string(forKey: "widget.intentionText") ?? ""
        return Snapshot(weekStart: weekStart, text: text)
    }

    static func currentISOWeekStart(now: Date = Date()) -> Date {
        weekStart(for: now)
    }

    static func weekStart(for date: Date) -> Date {
        let comps = watchCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return watchCalendar.date(from: comps) ?? watchCalendar.startOfDay(for: date)
    }

    static func startOfNextWeek(after date: Date) -> Date {
        let thisWeek = weekStart(for: date)
        return watchCalendar.date(byAdding: .weekOfYear, value: 1, to: thisWeek) ?? thisWeek
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseISODate(_ str: String?) -> Date? {
        guard let str else { return nil }
        return isoFormatter.date(from: str) ?? isoFormatterNoFrac.date(from: str)
    }
}

// MARK: - Week Range Formatting

private let watchCalendar: Calendar = {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    return cal
}()

private let watchWeekRangeDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = watchCalendar
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("MMM d")
    return df
}()

private func watchWeekRangeText(for weekStart: Date) -> String {
    let end = watchCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    return "\(watchWeekRangeDateFormatter.string(from: weekStart)) – \(watchWeekRangeDateFormatter.string(from: end))"
}

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
            weekStart: WatchSharedReader.currentISOWeekStart()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchIntentionEntry) -> Void) {
        let snap = WatchSharedReader.read()
        completion(WatchIntentionEntry(date: Date(), text: snap.text, weekStart: snap.weekStart))
    }

    /// Two-entry timeline: current snapshot, then an empty rollover entry pinned
    /// to next Monday 00:00. Matches the iOS widget's behavior — see
    /// `WeeklyIntentionWidget.swift` for the full rationale.
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchIntentionEntry>) -> Void) {
        let now = Date()
        let snap = WatchSharedReader.read()

        let currentWeek = WatchSharedReader.currentISOWeekStart(now: now)
        let snapshotIsForCurrentWeek = watchCalendar.isDate(
            snap.weekStart,
            inSameDayAs: currentWeek
        )

        let currentEntry: WatchIntentionEntry
        if snapshotIsForCurrentWeek {
            currentEntry = WatchIntentionEntry(date: now, text: snap.text, weekStart: snap.weekStart)
        } else {
            currentEntry = WatchIntentionEntry(date: now, text: "", weekStart: currentWeek)
        }

        let nextWeekStart = WatchSharedReader.startOfNextWeek(after: now)
        let rolloverEntry = WatchIntentionEntry(date: nextWeekStart, text: "", weekStart: nextWeekStart)

        let refreshAfter = watchCalendar.date(byAdding: .minute, value: 5, to: nextWeekStart)
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
            Text(watchWeekRangeText(for: entry.weekStart))
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
