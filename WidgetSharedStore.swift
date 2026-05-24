import Foundation
import WidgetKit

/// Monday-based ISO 8601 calendar used throughout the app and widgets.
let sharedCalendar: Calendar = {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2 // Monday
    return cal
}()

/// Cached DateFormatter for "MMM d" week-range labels (e.g. "Mar 10 – Mar 16").
private let weekRangeDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.calendar = sharedCalendar
    df.locale = .current
    df.setLocalizedDateFormatFromTemplate("MMM d")
    return df
}()

/// Returns a human-readable week range string like "Mar 10 – Mar 16".
func weekRangeText(for weekStart: Date) -> String {
    let end = sharedCalendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    return "\(weekRangeDateFormatter.string(from: weekStart)) – \(weekRangeDateFormatter.string(from: end))"
}

enum WidgetSharedStore {
    static let appGroupID = "group.com.uwebury.weeklyintention"

    // MARK: - WC / App Group keys
    //
    // Shared between the iOS app, the iOS widget, WatchConnectivity payloads, and
    // (once this file is added to the watch targets) the watch app + watch widget.
    // Centralised here so a typo on one side can't silently break the other.
    enum Keys {
        static let weekStartISO = "widget.weekStartISO"
        static let intentionText = "widget.intentionText"
        static let updatedAtISO = "widget.updatedAtISO"
    }

    static func writeCurrentWeekIntention(weekStart: Date, text: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(isoDateString(weekStart), forKey: Keys.weekStartISO)
        defaults.set(text, forKey: Keys.intentionText)
        defaults.set(isoDateString(Date()), forKey: Keys.updatedAtISO)

        // Prompt widgets to refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyIntentionWidget")
    }


    static func read() -> Snapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return Snapshot(weekStart: currentISOWeekStart(), text: "", updatedAt: nil)
        }

        let weekStart = parseISODate(defaults.string(forKey: Keys.weekStartISO)) ?? currentISOWeekStart()
        let text = defaults.string(forKey: Keys.intentionText) ?? ""
        let updatedAt = parseISODate(defaults.string(forKey: Keys.updatedAtISO))

        return Snapshot(weekStart: weekStart, text: text, updatedAt: updatedAt)
    }

    struct Snapshot {
        let weekStart: Date
        let text: String
        let updatedAt: Date?
    }

    // MARK: - ISO week helpers (Monday-based)

    /// Canonical "start of the ISO week containing `date`" (Monday 00:00 local).
    ///
    /// Uses `[.yearForWeekOfYear, .weekOfYear]` rather than weekday-delta math —
    /// both give the same answer with the ISO calendar, but the components-based
    /// approach is the documented Cocoa idiom and survives DST / calendar edge
    /// cases without subtle off-by-one risk. This is the single source of truth
    /// for week math: everywhere else routes through here.
    static func weekStart(for date: Date) -> Date {
        let comps = sharedCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return sharedCalendar.date(from: comps) ?? sharedCalendar.startOfDay(for: date)
    }

    static func currentISOWeekStart(now: Date = Date()) -> Date {
        weekStart(for: now)
    }

    /// Start of the ISO week immediately after `date`'s week.
    /// Used by widget timelines to schedule the Monday rollover entry.
    static func startOfNextWeek(after date: Date) -> Date {
        let thisWeek = weekStart(for: date)
        return sharedCalendar.date(byAdding: .weekOfYear, value: 1, to: thisWeek) ?? thisWeek
    }

    // MARK: - ISO date formatting

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

    static func isoDateString(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func parseISODate(_ str: String?) -> Date? {
        guard let str else { return nil }
        return isoFormatter.date(from: str) ?? isoFormatterNoFrac.date(from: str)
    }
}
