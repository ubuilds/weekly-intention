
import SwiftUI
import SwiftData
import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var stored: [WeeklyIntention]
    @Environment(AppState.self) private var appState
    @Environment(SyncStatus.self) private var syncStatus
    @Environment(CloudKitAccountStatus.self) private var iCloudAccountStatus

    private let calendar = sharedCalendar

    private let weeksBefore = 52
    private let weeksAfter  = 52

    @State private var selectedIndex: Int = 0
    @State private var editingWeekStart: Date?
    @State private var draftText: String = ""
    @State private var weeks: [Date] = []

    #if os(macOS)
    @FocusState private var macContentFocused: Bool
    #endif


    var body: some View {
        Group {
            #if os(iOS)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        selectedIndex = max(0, selectedIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex <= 0)

                    Button("Today") {
                        selectedIndex = weeksBefore
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(selectedIndex == weeksBefore)

                    Button {
                        selectedIndex = min(weeks.count - 1, selectedIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex >= weeks.count - 1)

                    Spacer()

                    statusPill

                    Button {
                        appState.presentRecall(focusSearch: true)
                    } label: {
                        Label("Recall", systemImage: "clock.arrow.circlepath")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recall")
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(weeks.enumerated()), id: \.element) { index, weekStart in
                        WeekSlide(
                            weekStart: weekStart,
                            calendar: calendar,
                            intentionText: intentionText(for: weekStart)
                        )
                        .tag(index)
                        .contentShape(Rectangle())
                        .onTapGesture { beginEdit(weekStart: weekStart) }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .onAppear { initWeeks() }

            #elseif os(macOS)
            // macOS: explicit navigation instead of an unlabeled TabView picker.
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        selectedIndex = max(0, selectedIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .disabled(selectedIndex <= 0)

                    Button("Today") {
                        selectedIndex = weeksBefore
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .keyboardShortcut("0", modifiers: [.command])
                    .help("Jump to current week (⌘0)")
                    .disabled(selectedIndex == weeksBefore)

                    Button {
                        selectedIndex = min(weeks.count - 1, selectedIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .disabled(selectedIndex >= weeks.count - 1)

                    Spacer()

                    statusPill

                    Button("Recall") {
                        appState.presentRecall(focusSearch: true)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Recall past intentions")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                let weekStart = currentWeekStart(from: weeks)
                WeekSlide(
                    weekStart: weekStart,
                    calendar: calendar,
                    intentionText: intentionText(for: weekStart)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    beginEdit(weekStart: weekStart)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    selectedIndex = max(0, selectedIndex - 1)
                case .right:
                    selectedIndex = min(weeks.count - 1, selectedIndex + 1)
                default:
                    break
                }
            }
            .focusable()
            .focused($macContentFocused)
            .focusEffectDisabled()
            .onAppear {
                initWeeks()
                macContentFocused = true
            }

            #else
            // visionOS (and any other platforms): use the swipeable week pager UI.
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button {
                        selectedIndex = max(0, selectedIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex <= 0)

                    Button("Today") {
                        selectedIndex = weeksBefore
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(selectedIndex == weeksBefore)

                    Button {
                        selectedIndex = min(weeks.count - 1, selectedIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedIndex >= weeks.count - 1)

                    Spacer()

                    statusPill

                    Button {
                        appState.presentRecall(focusSearch: true)
                    } label: {
                        Label("Recall", systemImage: "clock.arrow.circlepath")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recall")
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(weeks.enumerated()), id: \.element) { index, weekStart in
                        WeekSlide(
                            weekStart: weekStart,
                            calendar: calendar,
                            intentionText: intentionText(for: weekStart)
                        )
                        .tag(index)
                        .contentShape(Rectangle())
                        .onTapGesture { beginEdit(weekStart: weekStart) }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .onAppear { initWeeks() }
            #endif
        }
        .sheet(item: editingWeekStartDateItem) { (item: DateItem) in
            EditIntentionSheet(
                weekStart: item.date,
                calendar: calendar,
                text: $draftText,
                onSave: {
                    saveIntention(weekStart: item.date, text: draftText)
                }
            )
            #if os(iOS)
            .presentationDetents([.medium])
            #endif
        }
        .sheet(isPresented: Bindable(appState).isRecallPresented) {
            RecallSheet(
                calendar: calendar,
                items: stored,
                onPickWeekStart: { picked in
                    if let idx = indexForWeekStart(picked, within: weeks) {
                        selectedIndex = idx
                    }
                    appState.isRecallPresented = false
                },
                onClose: {
                    appState.isRecallPresented = false
                }
            )
            .environment(appState)
        }
    }

    // MARK: - Status pill

    /// Single status indicator shown in the nav bar. iCloud-account problems take
    /// precedence over network/sync state — without iCloud, "Offline" is misleading
    /// because the real problem is that nothing will ever sync. Show at most one
    /// pill to keep the chrome calm (vision: minimal).
    @ViewBuilder
    private var statusPill: some View {
        if let label = iCloudAccountStatus.labelText {
            pillView(label: label, accessibility: iCloudAccountStatus.accessibilityDescription ?? label)
        } else if let label = syncStatus.labelText {
            pillView(label: label, accessibility: label)
        }
    }

    private func pillView(label: String, accessibility: String) -> some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel(accessibility)
    }

    // MARK: - Week helpers

    private func currentWeekStart(from weeks: [Date]) -> Date {
        weeks[safe: selectedIndex] ?? WidgetSharedStore.currentISOWeekStart()
    }

    private func initWeeks() {
        weeks = weekStartsAroundNow()
        selectedIndex = weeksBefore
    }

    private func weekStartsAroundNow() -> [Date] {
        let currentStart = WidgetSharedStore.currentISOWeekStart()
        return (-weeksBefore...weeksAfter).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: offset, to: currentStart)
        }
    }

    private func indexForWeekStart(_ weekStart: Date, within weeks: [Date]) -> Int? {
        weeks.firstIndex(where: { calendar.isDate($0, inSameDayAs: weekStart) })
    }

    /// O(1) lookup table built from `@Query` results. Recomputed only when
    /// `stored` changes (SwiftUI re-evaluates `body`, this computed property
    /// runs once per body), then used by every visible WeekSlide.
    private var intentionsByWeekStart: [Date: String] {
        // If duplicates exist (CloudKit conflict not yet converged), prefer the
        // most recently updated row; fall back to longest text for legacy rows
        // whose updatedAt is .distantPast.
        var byWeek: [Date: WeeklyIntention] = [:]
        for item in stored {
            let key = WidgetSharedStore.weekStart(for: item.weekStart)
            if let existing = byWeek[key] {
                if shouldPrefer(item, over: existing) {
                    byWeek[key] = item
                }
            } else {
                byWeek[key] = item
            }
        }
        return byWeek.mapValues { $0.text }
    }

    private func intentionText(for weekStart: Date) -> String {
        intentionsByWeekStart[WidgetSharedStore.weekStart(for: weekStart)] ?? ""
    }

    private func beginEdit(weekStart: Date) {
        draftText = intentionText(for: weekStart)
        editingWeekStart = weekStart
    }

    private func saveIntention(weekStart: Date, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        // Enforce “one intention per week” in code (CloudKit does not support unique constraints).
        let matches = stored.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }

        if trimmed.isEmpty {
            // If cleared, delete all entries for this week.
            for item in matches {
                modelContext.delete(item)
            }
        } else if !matches.isEmpty {
            // Update the "best" matching entry (most recently updated, longest on
            // legacy ties), then delete the rest. Picking by updatedAt rather than
            // array order means we don't preserve the wrong row when CloudKit has
            // surfaced duplicates.
            let keeper = matches.reduce(matches[0]) { best, candidate in
                shouldPrefer(candidate, over: best) ? candidate : best
            }
            keeper.text = trimmed
            keeper.updatedAt = now

            for dup in matches where dup !== keeper {
                modelContext.delete(dup)
            }
        } else {
            // No entry yet for this week.
            modelContext.insert(WeeklyIntention(weekStart: weekStart, text: trimmed, updatedAt: now))
        }

        // Persist changes explicitly so CloudKit can propagate them across devices.
        // The widget cache + watch push only run on a successful save — otherwise
        // the widget would advertise text that isn't actually stored, violating
        // the "convergence" principle.
        do {
            try modelContext.save()
        } catch {
            print("SwiftData save failed:", error)
            return
        }

        // If the user edited the CURRENT week, update the widget cache too.
        let currentWeek = WidgetSharedStore.currentISOWeekStart()
        if calendar.isDate(weekStart, inSameDayAs: currentWeek) {
            WidgetSharedStore.writeCurrentWeekIntention(weekStart: currentWeek, text: trimmed)

            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyIntentionWidget")
            #endif

            // Push to Apple Watch via WatchConnectivity
            #if canImport(WatchConnectivity)
            PhoneToWatchConnector.shared.sendIntention(
                weekStartISO: WidgetSharedStore.isoDateString(currentWeek),
                text: trimmed
            )
            #endif
        }
    }

    private struct DateItem: Identifiable {
        let id: Date
        let date: Date
    }

    private var editingWeekStartDateItem: Binding<DateItem?> {
        Binding<DateItem?>(
            get: { editingWeekStart.map { DateItem(id: $0, date: $0) } },
            set: { editingWeekStart = $0?.date }
        )
    }
}

private struct RecallSheet: View {
    let calendar: Calendar
    let items: [WeeklyIntention]
    let onPickWeekStart: (Date) -> Void
    let onClose: () -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case list, grid
        var id: Self { self }
        var label: String {
            switch self {
            case .list: return "List"
            case .grid: return "Grid"
            }
        }
    }

    @State private var searchText: String = ""
    @State private var mode: Mode = .list
    @State private var exportFileURL: URL?
    @Environment(AppState.self) private var appState
    @FocusState private var isSearchFocused: Bool

    /// Deduped intentions keyed by `weekStart`. Single pass over `items` shared
    /// by both List (rendered as a sorted array) and Grid (looked up by date).
    private var dedupedByWeekStart: [Date: WeeklyIntention] {
        var byWeek: [Date: WeeklyIntention] = [:]
        for item in items {
            if let existing = byWeek[item.weekStart] {
                if shouldPrefer(item, over: existing) {
                    byWeek[item.weekStart] = item
                }
            } else {
                byWeek[item.weekStart] = item
            }
        }
        return byWeek
    }

    private var sortedItems: [WeeklyIntention] {
        let base = Array(dedupedByWeekStart.values).sorted { $0.weekStart > $1.weekStart }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        switch mode {
                        case .list:
                            listContent
                        case .grid:
                            RecallGridView(
                                calendar: calendar,
                                intentionsByWeekStart: dedupedByWeekStart,
                                onPickWeekStart: onPickWeekStart
                            )
                        }
                    }
                }
            }
            .navigationTitle("Recall")
            // Search applies to List mode only — Grid mode is for scanning the
            // whole year visually, not filtering it down.
            .modifier(SearchableInListMode(mode: mode, searchText: $searchText, isSearchFocused: $isSearchFocused))
            .onAppear {
                if appState.shouldFocusRecallSearch {
                    appState.shouldFocusRecallSearch = false
                    // Defer focus so SwiftUI has attached the searchable field.
                    Task { @MainActor in
                        isSearchFocused = true
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !items.isEmpty, let url = exportFileURL {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export intentions")
                    }
                }
            }
            .task(id: items.count) {
                exportFileURL = generateExportFile()
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        #endif

        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    // MARK: - Export

    /// Builds a Markdown file of every stored intention, grouped by ISO year,
    /// sorted most-recent first. Returns a temp URL suitable for ShareLink — the
    /// `.md` extension drives the suggested filename in Files / iCloud Drive /
    /// AirDrop receivers. Returns `nil` when there's nothing to export or the
    /// write fails.
    ///
    /// Lives entirely on-device: the markdown string is built locally, written
    /// to the process's temporary directory, and shared via the system share
    /// sheet. No network, no third-party services — matches the "your data is
    /// yours" stance from the vision.
    private func generateExportFile() -> URL? {
        let markdown = buildExportMarkdown()
        guard !markdown.isEmpty else { return nil }

        let filename = "WeeklyIntentions-\(exportDateStamp()).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Export write failed:", error)
            return nil
        }
    }

    private func buildExportMarkdown() -> String {
        let deduped = Array(dedupedByWeekStart.values).sorted { $0.weekStart > $1.weekStart }
        guard !deduped.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("# Weekly Intentions")
        lines.append("")
        lines.append("*Exported \(exportTodayLongString())*")
        lines.append("")

        var currentYear: Int?
        for item in deduped {
            let year = sharedCalendar.component(.yearForWeekOfYear, from: item.weekStart)
            let week = sharedCalendar.component(.weekOfYear, from: item.weekStart)
            if year != currentYear {
                lines.append("## \(year)")
                lines.append("")
                currentYear = year
            }
            let range = weekRangeText(for: item.weekStart)
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append("### Week \(week) — \(range)")
            lines.append("")
            lines.append(text)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func exportTodayLongString() -> String {
        let df = DateFormatter()
        df.calendar = sharedCalendar
        df.locale = .current
        df.dateStyle = .long
        return df.string(from: Date())
    }

    private func exportDateStamp() -> String {
        let df = DateFormatter()
        df.calendar = sharedCalendar
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No past intentions yet")
                .font(.headline)

            Text("Set an intention for any week, then use Recall to jump back to it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button("Close") { onClose() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var listContent: some View {
        if sortedItems.isEmpty {
            // Non-empty `items` but the search filtered them all out.
            VStack(spacing: 8) {
                Text("No matching intentions")
                    .font(.headline)
                Text("Try a different search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List {
                ForEach(sortedItems, id: \.id) { item in
                    Button {
                        onPickWeekStart(item.weekStart)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(weekRangeText(for: item.weekStart))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines))
                                .font(.body)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

/// Wraps `.searchable` so we can attach it only when the Recall sheet is in
/// List mode — Grid mode doesn't need it and the field would just take up space.
private struct SearchableInListMode: ViewModifier {
    let mode: RecallSheet.Mode
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        switch mode {
        case .list:
            content
                .searchable(text: $searchText, prompt: "Search intentions")
                .searchFocused(isSearchFocused)
        case .grid:
            content
        }
    }
}

/// Year-at-a-glance view: every ISO week of a chosen year rendered as a tile.
/// Filled tiles have an intention; empty tiles are still tappable so the user
/// can jump to that week and write one. No streaks, no colour gradients, no
/// scoring — just presence, in the spirit of "look back without judgement."
private struct RecallGridView: View {
    let calendar: Calendar
    let intentionsByWeekStart: [Date: WeeklyIntention]
    let onPickWeekStart: (Date) -> Void

    @State private var displayedYear: Int = sharedCalendar.component(.yearForWeekOfYear, from: Date())

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            yearNavigator
                .padding(.horizontal)
                .padding(.vertical, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(cells, id: \.weekStart) { cell in
                        cellView(for: cell)
                            .onTapGesture {
                                onPickWeekStart(cell.weekStart)
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Year navigator

    @ViewBuilder
    private var yearNavigator: some View {
        let years = availableYears
        HStack(spacing: 16) {
            Button {
                if let prev = previousYear(in: years) { displayedYear = prev }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .disabled(previousYear(in: years) == nil)

            Text(verbatim: String(displayedYear))
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 64)

            Button {
                if let next = nextYear(in: years) { displayedYear = next }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(nextYear(in: years) == nil)
        }
        .frame(maxWidth: .infinity)
    }

    /// The set of years that have at least one intention, plus the current year
    /// (so the grid can always show "now" even with no data yet).
    private var availableYears: [Int] {
        let currentYear = sharedCalendar.component(.yearForWeekOfYear, from: Date())
        let dataYears = Set(intentionsByWeekStart.keys.map {
            sharedCalendar.component(.yearForWeekOfYear, from: $0)
        })
        return Array(dataYears.union([currentYear])).sorted()
    }

    private func previousYear(in years: [Int]) -> Int? {
        years.last(where: { $0 < displayedYear })
    }

    private func nextYear(in years: [Int]) -> Int? {
        years.first(where: { $0 > displayedYear })
    }

    // MARK: - Grid cells

    private struct WeekCell {
        let weekStart: Date
        let weekNumber: Int
        let intention: WeeklyIntention?
        let isCurrentWeek: Bool
    }

    private var cells: [WeekCell] {
        let now = Date()
        let currentWeekStart = WidgetSharedStore.currentISOWeekStart(now: now)

        // ISO weeks in `displayedYear` (52 most years, 53 occasionally).
        guard let weekCount = weeksInYear(displayedYear) else { return [] }

        return (1...weekCount).compactMap { weekNumber -> WeekCell? in
            var comps = DateComponents()
            comps.yearForWeekOfYear = displayedYear
            comps.weekOfYear = weekNumber
            comps.weekday = sharedCalendar.firstWeekday
            guard let weekStart = sharedCalendar.date(from: comps) else { return nil }

            let normalisedStart = WidgetSharedStore.weekStart(for: weekStart)
            return WeekCell(
                weekStart: normalisedStart,
                weekNumber: weekNumber,
                intention: intentionsByWeekStart[normalisedStart],
                isCurrentWeek: sharedCalendar.isDate(normalisedStart, inSameDayAs: currentWeekStart)
            )
        }
    }

    private func weeksInYear(_ year: Int) -> Int? {
        // Last Thursday of the year is always in the last ISO week — pick a
        // mid-December date and ask the calendar how many weeks the
        // year-for-weekOfYear has.
        var comps = DateComponents()
        comps.year = year
        comps.month = 12
        comps.day = 28
        guard let date = sharedCalendar.date(from: comps) else { return nil }
        return sharedCalendar.range(of: .weekOfYear, in: .yearForWeekOfYear, for: date)?.count
    }

    // MARK: - Cell rendering

    @ViewBuilder
    private func cellView(for cell: WeekCell) -> some View {
        let trimmed = cell.intention?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasIntention = !trimmed.isEmpty

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Wk \(cell.weekNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if cell.isCurrentWeek {
                    Circle()
                        .fill(.tint)
                        .frame(width: 6, height: 6)
                }
            }

            if hasIntention {
                Text(trimmed)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text(shortRangeText(for: cell.weekStart))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(8)
        .frame(minHeight: 72, maxHeight: 96)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hasIntention ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    cell.isCurrentWeek
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(Color.secondary.opacity(0.25)),
                    lineWidth: cell.isCurrentWeek ? 1.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: cell, hasIntention: hasIntention, trimmed: trimmed))
    }

    private func shortRangeText(for weekStart: Date) -> String {
        weekRangeText(for: weekStart)
    }

    private func accessibilityLabel(for cell: WeekCell, hasIntention: Bool, trimmed: String) -> String {
        let range = weekRangeText(for: cell.weekStart)
        if hasIntention {
            return "Week \(cell.weekNumber), \(range). \(trimmed)"
        } else {
            return "Week \(cell.weekNumber), \(range). No intention."
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

/// Returns `true` when `candidate` should win a duplicate-resolution tiebreak
/// against `incumbent`. Prefer the more recently updated row; when `updatedAt`
/// ties (e.g. both legacy rows at `.distantPast`), prefer the longer trimmed
/// text — a best-effort guess at "the real intention" rather than the empty
/// or truncated one.
fileprivate func shouldPrefer(_ candidate: WeeklyIntention, over incumbent: WeeklyIntention) -> Bool {
    if candidate.updatedAt != incumbent.updatedAt {
        return candidate.updatedAt > incumbent.updatedAt
    }
    let candidateLen = candidate.text.trimmingCharacters(in: .whitespacesAndNewlines).count
    let incumbentLen = incumbent.text.trimmingCharacters(in: .whitespacesAndNewlines).count
    return candidateLen > incumbentLen
}
