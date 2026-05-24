import Foundation
import SwiftData

@Model
final class WeeklyIntention {
    // CloudKit requires default values for non-optional attributes.
    var weekStart: Date = Date.distantPast
    var text: String = ""

    // Stable identity for CloudKit.
    var id: UUID = UUID()

    /// Wall-clock time of the most recent write. Used as the tiebreaker when
    /// CloudKit surfaces multiple rows for the same `weekStart` (last write wins).
    ///
    /// Defaulted to `.distantPast` so existing rows migrated from older schema
    /// versions sort below anything written after this field shipped; the
    /// length-based heuristic in `RecallSheet` still breaks ties among legacy rows.
    var updatedAt: Date = Date.distantPast

    init(weekStart: Date, text: String = "", updatedAt: Date = Date()) {
        self.weekStart = weekStart
        self.text = text
        self.updatedAt = updatedAt
    }
}
