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

    private static let keyWeekStartISO = "widget.weekStartISO"
    private static let keyIntentionText = "widget.intentionText"
    private static let keyUpdatedAt = "widget.updatedAtISO"

    static func writeCurrentWeekIntention(weekStart: Date, text: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        defaults.set(isoDateString(weekStart), forKey: keyWeekStartISO)
        defaults.set(text, forKey: keyIntentionText)
        defaults.set(isoDateString(Date()), forKey: keyUpdatedAt)

        // Prompt widgets to refresh
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyIntentionWidget")
    }


    static func read() -> Snapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return Snapshot(weekStart: currentISOWeekStart(), text: "", updatedAt: nil)
        }

        let weekStart = parseISODate(defaults.string(forKey: keyWeekStartISO)) ?? currentISOWeekStart()
        let text = defaults.string(forKey: keyIntentionText) ?? ""
        let updatedAt = parseISODate(defaults.string(forKey: keyUpdatedAt))

        return Snapshot(weekStart: weekStart, text: text, updatedAt: updatedAt)
    }

    struct Snapshot {
        let weekStart: Date
        let text: String
        let updatedAt: Date?
    }

    // MARK: - ISO week helpers (Monday-based)

    static func currentISOWeekStart(now: Date = Date()) -> Date {
        let startOfDay = sharedCalendar.startOfDay(for: now)
        let weekday = sharedCalendar.component(.weekday, from: startOfDay)
        let delta = (weekday + 5) % 7
        return sharedCalendar.date(byAdding: .day, value: -delta, to: startOfDay) ?? startOfDay
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

    private static func parseISODate(_ str: String?) -> Date? {
        guard let str else { return nil }
        return isoFormatter.date(from: str) ?? isoFormatterNoFrac.date(from: str)
    }
}
