
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
                    ForEach(Array(weeks.enumerated()), id: \.offset) { index, weekStart in
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
                    ForEach(Array(weeks.enumerated()), id: \.offset) { index, weekStart in
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

    @State private var searchText: String = ""
    @Environment(AppState.self) private var appState
    @FocusState private var isSearchFocused: Bool

    private var sortedItems: [WeeklyIntention] {
        // Defensive read-side dedupe: CloudKit can surface multiple rows for the
        // same weekStart if two devices wrote before convergence. saveIntention()
        // enforces one-per-week on write, but stale duplicates may still exist.
        // Prefer the most recently updated row; fall back to longest text for
        // legacy rows whose updatedAt is .distantPast.
        let deduped = Dictionary(grouping: items, by: { $0.weekStart })
            .values
            .compactMap { group -> WeeklyIntention? in
                group.reduce(nil) { (best: WeeklyIntention?, candidate: WeeklyIntention) in
                    guard let best else { return candidate }
                    return shouldPrefer(candidate, over: best) ? candidate : best
                }
            }

        let base = deduped.sorted { $0.weekStart > $1.weekStart }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedItems.isEmpty {
                    VStack(spacing: 12) {
                        Text(searchText.isEmpty ? "No past intentions yet" : "No matching intentions")
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
                                // Uses global weekRangeText(for:)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Recall")
            .searchable(text: $searchText, prompt: "Search intentions")
            .searchFocused($isSearchFocused)
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
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 420)
        #endif

        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
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
