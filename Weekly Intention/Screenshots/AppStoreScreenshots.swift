#if DEBUG
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

// MARK: - Spec

/// App Store screenshot pixel sizes (Jan 2026 App Store Connect requirements).
/// View is laid out in points; ImageRenderer multiplies by `scale` to reach pixel size.
enum AppStoreScreenshotSize {
    case iPhone69       // 1320 × 2868 px — iPhone 16 Pro Max display
    case iPad13         // 2064 × 2752 px — iPad Pro 13" (M4)
    case watchUltra     // 410  × 502  px — Apple Watch Ultra

    var pointSize: CGSize {
        switch self {
        case .iPhone69:   return CGSize(width: 440,  height: 956)
        case .iPad13:     return CGSize(width: 1032, height: 1376)
        case .watchUltra: return CGSize(width: 205,  height: 251)
        }
    }

    var scale: CGFloat {
        switch self {
        case .iPhone69:   return 3
        case .iPad13, .watchUltra: return 2
        }
    }

    var pixelSize: CGSize {
        CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
    }
}

// MARK: - Captioned composition

/// One captioned App Store screenshot: caption above, framed app content below.
struct CaptionedAppStoreScreenshot<Content: View>: View {
    let size: AppStoreScreenshotSize
    let caption: String
    let subcaption: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.98),
                    Color(red: 0.86, green: 0.89, blue: 0.93)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: metrics.subcaptionGap) {
                    Text(caption)
                        .font(.system(size: metrics.captionFont, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineSpacing(metrics.captionFont * 0.08)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subcaption {
                        Text(subcaption)
                            .font(.system(size: metrics.subcaptionFont, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineSpacing(metrics.subcaptionFont * 0.1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, metrics.sidePadding)
                .padding(.top, metrics.topPadding)

                Spacer(minLength: metrics.captionToContentGap)

                content()
                    .frame(width: metrics.contentWidth, height: metrics.contentHeight)
                    .clipShape(RoundedRectangle(cornerRadius: metrics.contentRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.contentRadius, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: metrics.shadowRadius, x: 0, y: metrics.shadowY)

                Spacer(minLength: metrics.bottomPadding)
            }
        }
        .frame(width: size.pointSize.width, height: size.pointSize.height)
        .environment(\.colorScheme, .light)
    }

    private var metrics: Metrics { Metrics(size: size) }

    private struct Metrics {
        let size: AppStoreScreenshotSize

        var captionFont: CGFloat {
            switch size {
            case .iPhone69:   return 38
            case .iPad13:     return 54
            case .watchUltra: return 15
            }
        }
        var subcaptionFont: CGFloat { captionFont * 0.55 }
        var subcaptionGap: CGFloat  { captionFont * 0.28 }
        var sidePadding: CGFloat    { size.pointSize.width * 0.08 }
        var topPadding: CGFloat     { size.pointSize.height * 0.07 }
        var bottomPadding: CGFloat  { size.pointSize.height * 0.06 }
        var captionToContentGap: CGFloat { size.pointSize.height * 0.04 }

        var contentWidth: CGFloat {
            switch size {
            case .iPhone69:   return size.pointSize.width * 0.86  // ~379
            case .iPad13:     return size.pointSize.width * 0.74  // ~764 — narrower so it reads as content, not a stretched square
            case .watchUltra: return size.pointSize.width * 0.65  // ~133 — portrait, matches the watch screen aspect
            }
        }

        var contentHeight: CGFloat {
            switch size {
            case .iPhone69:   return size.pointSize.height * 0.62  // ~593
            case .iPad13:     return size.pointSize.height * 0.78  // ~1073 — taller so the recall list fills, not collapses
            case .watchUltra: return size.pointSize.height * 0.66  // ~166 — taller than contentWidth so it reads as a watch
            }
        }

        /// Concentric-ish with each device's screen corner. Iphone 16 Pro Max ≈ 55, iPad ≈ 18.
        /// Kept modest so chevrons in the top-left of mock content don't get clipped.
        var contentRadius: CGFloat {
            switch size {
            case .iPhone69:   return 32
            case .iPad13:     return 24
            case .watchUltra: return 14
            }
        }
        var shadowRadius: CGFloat   { size.pointSize.width * 0.04 }
        var shadowY: CGFloat        { size.pointSize.width * 0.018 }
    }
}

// MARK: - Mock content views (preview-only, no SwiftData / no CloudKit)

private let mockWeekStart: Date = {
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 5
    comps.day = 18
    return sharedCalendar.date(from: comps) ?? Date()
}()

/// Real WeekSlide with mock data — same component the app actually renders.
private struct MockMainScreen: View {
    let intention: String

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.99, blue: 1.0)

            VStack(spacing: 0) {
                MockNavBar()
                WeekSlide(
                    weekStart: mockWeekStart,
                    calendar: sharedCalendar,
                    intentionText: intention
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
    }
}

private struct MockNavBar: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left").foregroundStyle(.secondary)
            Text("Today").font(.body).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            Spacer()
            Text("Synced")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

private struct MockEditSheet: View {
    let draft: String

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.97, green: 0.97, blue: 0.98)

            VStack(spacing: 0) {
                HStack {
                    Text("Cancel").foregroundStyle(.blue)
                    Spacer()
                    Text("Weekly Intention").font(.headline)
                    Spacer()
                    Text("Save").foregroundStyle(.blue).bold()
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))

                VStack(alignment: .leading, spacing: 14) {
                    Text(weekRangeText(for: mockWeekStart))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                        Text(draft)
                            .font(.title3)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(18)
            }
        }
    }
}

private struct MockRecall: View {
    struct Item: Identifiable { let id = UUID(); let range: String; let text: String }
    let items: [Item]

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.98, green: 0.98, blue: 0.99)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    Text("Search intentions").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 18)

                VStack(spacing: 0) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.range)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(item.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        Divider().padding(.leading, 18)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

// MARK: - Faithful widget renders

/// Faithful render of WeeklyIntentionWidgetView (see WeeklyIntentionWidget.swift) at the iPhone Home Screen "small" size (158×158 pt).
private struct FaithfulWidgetSmall: View {
    let intention: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weekRangeText(for: mockWeekStart))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(intention)
                .font(.headline)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .frame(width: 158, height: 158)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Faithful render of WeeklyIntentionWidgetView at the iPhone Home Screen "medium" size (338×158 pt).
private struct FaithfulWidgetMedium: View {
    let intention: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weekRangeText(for: mockWeekStart))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(intention)
                .font(.headline)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .frame(width: 338, height: 158)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Faithful render of WeeklyIntentionWidgetView at the iPadOS "large" size (364×382 pt).
private struct FaithfulWidgetLarge: View {
    let intention: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weekRangeText(for: mockWeekStart))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(intention)
                .font(.headline)
                .lineLimit(8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .frame(width: 364, height: 382)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Clean widget composition — no fake home-screen chrome. Just the actual widget tile(s) on a soft gradient.
private struct WidgetShowcase: View {
    enum Layout { case iPhoneSmallPlusMedium, iPadMediumPlusLarge }
    let layout: Layout
    let intention: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.94, blue: 0.97), Color(red: 0.80, green: 0.84, blue: 0.91)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 24) {
                Spacer(minLength: 0)
                switch layout {
                case .iPhoneSmallPlusMedium:
                    FaithfulWidgetSmall(intention: intention)
                        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                    FaithfulWidgetMedium(intention: intention)
                        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                case .iPadMediumPlusLarge:
                    FaithfulWidgetMedium(intention: intention)
                        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                    FaithfulWidgetLarge(intention: intention)
                        .shadow(color: .black.opacity(0.15), radius: 14, y: 6)
                }
                Spacer(minLength: 0)
            }
            .padding()
        }
    }
}

private struct MockWatchApp: View {
    let intention: String

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 6) {
                Spacer()
                Text("This week")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text(intention)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(4)
                Spacer()
            }
        }
    }
}

/// Faithful render of the watchOS Smart Stack rectangular widget — mirrors `RectangularView` in WeeklyIntentionWatchWidget.swift.
private struct MockWatchSmartStack: View {
    let intention: String

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.15))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weekRangeText(for: mockWeekStart))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(intention)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 70)
                .padding(.horizontal, 10)
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Screenshot catalog

struct AppStoreScreenshotSpec: Identifiable {
    let id: String
    let size: AppStoreScreenshotSize
    let caption: String
    let subcaption: String?
    let content: AnyView
}

private let sampleIntention = "Finish the watch release."
private let recallItems: [MockRecall.Item] = [
    .init(range: "May 11 – May 17", text: "Ship the security audit."),
    .init(range: "May 4 – May 10",  text: "Walk every morning before work."),
    .init(range: "Apr 27 – May 3",  text: "Write the vision document."),
    .init(range: "Apr 20 – Apr 26", text: "Rest. Read more, do less."),
    .init(range: "Apr 13 – Apr 19", text: "Talk to three independent builders."),
    .init(range: "Apr 6 – Apr 12",  text: "Refactor the week-math layer."),
    .init(range: "Mar 30 – Apr 5",  text: "Sketch the Lock Screen widget."),
    .init(range: "Mar 23 – Mar 29", text: "Finish the App Store listing refresh."),
    .init(range: "Mar 16 – Mar 22", text: "Watch the sunrise three times.")
]

let allAppStoreScreenshots: [AppStoreScreenshotSpec] = [
    // iPhone — 5 shots
    AppStoreScreenshotSpec(
        id: "iphone-1-one-clear-intention",
        size: .iPhone69,
        caption: "One clear intention\neach week.",
        subcaption: "Set what matters. Let the rest go.",
        content: AnyView(MockMainScreen(intention: sampleIntention))
    ),
    AppStoreScreenshotSpec(
        id: "iphone-2-change-anytime",
        size: .iPhone69,
        caption: "Change it any time.",
        subcaption: "No streaks. No penalty. No judgement.",
        content: AnyView(MockEditSheet(draft: "Finish the watch release."))
    ),
    AppStoreScreenshotSpec(
        id: "iphone-3-recall",
        size: .iPhone69,
        caption: "Look back\nwithout judgement.",
        subcaption: "Every past week, searchable.",
        content: AnyView(MockRecall(items: recallItems))
    ),
    AppStoreScreenshotSpec(
        id: "iphone-4-widget",
        size: .iPhone69,
        caption: "Always one glance away.",
        subcaption: "Home Screen widget — small and medium.",
        content: AnyView(WidgetShowcase(layout: .iPhoneSmallPlusMedium, intention: sampleIntention))
    ),

    // iPad — 3 shots
    AppStoreScreenshotSpec(
        id: "ipad-1-one-clear-intention",
        size: .iPad13,
        caption: "One clear intention each week.",
        subcaption: "On iPad, room for the week.",
        content: AnyView(MockMainScreen(intention: sampleIntention))
    ),
    AppStoreScreenshotSpec(
        id: "ipad-2-recall",
        size: .iPad13,
        caption: "Past intentions, searchable.",
        subcaption: "Every week you've held, one tap away.",
        content: AnyView(MockRecall(items: recallItems))
    ),
    AppStoreScreenshotSpec(
        id: "ipad-3-widget",
        size: .iPad13,
        caption: "On the Home Screen, too.",
        subcaption: "Medium and large widgets, side by side.",
        content: AnyView(WidgetShowcase(layout: .iPadMediumPlusLarge, intention: sampleIntention))
    ),

    // Apple Watch — 2 shots
    AppStoreScreenshotSpec(
        id: "watch-1-app",
        size: .watchUltra,
        caption: "On your wrist.",
        subcaption: nil,
        content: AnyView(MockWatchApp(intention: sampleIntention))
    ),
    AppStoreScreenshotSpec(
        id: "watch-2-smart-stack",
        size: .watchUltra,
        caption: "Right where your week starts.",
        subcaption: nil,
        content: AnyView(MockWatchSmartStack(intention: sampleIntention))
    )
]

// MARK: - PNG export

@MainActor
func exportAllAppStoreScreenshots() -> URL? {
    guard let outputDir = resolveScreenshotsOutputDirectory() else {
        print("Screenshots: could not create an output directory.")
        return nil
    }
    print("Screenshots: writing to \(outputDir.path)")

    for spec in allAppStoreScreenshots {
        let view = CaptionedAppStoreScreenshot(
            size: spec.size,
            caption: spec.caption,
            subcaption: spec.subcaption,
            content: { spec.content }
        )

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: spec.size.pointSize.width, height: spec.size.pointSize.height)
        renderer.scale = spec.size.scale

        guard let cgImage = renderer.cgImage else {
            print("Screenshots: render failed for \(spec.id)")
            continue
        }

        let url = outputDir.appendingPathComponent("\(spec.id).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("Screenshots: destination create failed for \(spec.id)")
            continue
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        if !CGImageDestinationFinalize(dest) {
            print("Screenshots: PNG finalize failed for \(spec.id)")
            continue
        }

        let px = spec.size.pixelSize
        print("Screenshots: wrote \(url.path) at \(Int(px.width))×\(Int(px.height)) px")
    }

    #if os(macOS)
    NSWorkspace.shared.activateFileViewerSelecting([outputDir])
    #endif

    return outputDir
}

/// Tries a prioritized list of output locations and returns the first one the sandbox allows.
/// Every attempt is logged so failures are diagnosable.
private func resolveScreenshotsOutputDirectory() -> URL? {
    let fm = FileManager.default
    let folderName = "WeeklyIntentionScreenshots"
    let env = ProcessInfo.processInfo.environment

    print("Screenshots: NSHomeDirectory() = \(NSHomeDirectory())")
    print("Screenshots: NSTemporaryDirectory() = \(NSTemporaryDirectory())")
    if let hostHome = env["SIMULATOR_HOST_HOME"] {
        print("Screenshots: SIMULATOR_HOST_HOME = \(hostHome)")
    } else {
        print("Screenshots: SIMULATOR_HOST_HOME not set.")
    }

    var candidates: [(name: String, url: URL)] = []

    if let hostHome = env["SIMULATOR_HOST_HOME"] {
        candidates.append(("Host Desktop (SIMULATOR_HOST_HOME)",
                           URL(fileURLWithPath: hostHome)
                               .appendingPathComponent("Desktop", isDirectory: true)
                               .appendingPathComponent(folderName, isDirectory: true)))
    }

    if let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
        candidates.append(("FileManager Desktop", desktop.appendingPathComponent(folderName, isDirectory: true)))
    }

    if let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
        candidates.append(("FileManager Documents", documents.appendingPathComponent(folderName, isDirectory: true)))
    }

    candidates.append(("App Documents (raw)",
                       URL(fileURLWithPath: NSHomeDirectory())
                           .appendingPathComponent("Documents", isDirectory: true)
                           .appendingPathComponent(folderName, isDirectory: true)))

    // Temp is almost always writable — final fallback.
    candidates.append(("Temp", fm.temporaryDirectory.appendingPathComponent(folderName, isDirectory: true)))

    for (name, url) in candidates {
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
            // Quick writability probe to be sure.
            let probe = url.appendingPathComponent(".probe")
            try Data().write(to: probe)
            try? fm.removeItem(at: probe)
            print("Screenshots: ✅ using \(name) → \(url.path)")
            return url
        } catch {
            print("Screenshots: ❌ \(name) → \(url.path) — \(error.localizedDescription)")
        }
    }
    return nil
}

// MARK: - Previews

/// Overview preview with a tap-to-export button and a status line.
private struct ScreenshotsOverviewPreview: View {
    @State private var status: String = "Click the button to export 10 PNGs."

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button {
                    print("Screenshots: Export tapped.")
                    status = "Exporting…"
                    Task { @MainActor in
                        if let dir = exportAllAppStoreScreenshots() {
                            status = "Wrote 10 PNGs to:\n\(dir.path)"
                        } else {
                            status = "Export failed — check the Xcode console."
                        }
                    }
                } label: {
                    Label("Export all PNGs", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.top, 12)

                Text(status)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                ForEach(allAppStoreScreenshots) { spec in
                    VStack(spacing: 6) {
                        Text("\(spec.id) — \(Int(spec.size.pixelSize.width))×\(Int(spec.size.pixelSize.height)) px")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)

                        CaptionedAppStoreScreenshot(
                            size: spec.size,
                            caption: spec.caption,
                            subcaption: spec.subcaption,
                            content: { spec.content }
                        )
                        .scaleEffect(previewScale(for: spec.size))
                        .frame(
                            width:  spec.size.pointSize.width  * previewScale(for: spec.size),
                            height: spec.size.pointSize.height * previewScale(for: spec.size)
                        )
                        .background(Color.gray.opacity(0.1))
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

#Preview("All screenshots — overview") {
    ScreenshotsOverviewPreview()
}

/// Auto-export preview — renders & writes the 10 PNGs the moment the preview appears.
/// Use this if the button-based preview isn't responsive.
private struct AutoExportPreview: View {
    @State private var status: String = "Preparing…"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Auto-exporting screenshots")
                .font(.headline)
            Text(status)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            print("Screenshots: AutoExportPreview appeared — exporting.")
            if let dir = exportAllAppStoreScreenshots() {
                status = "Wrote 10 PNGs to:\n\(dir.path)"
            } else {
                status = "Export failed — check the Xcode console."
            }
        }
    }
}

#Preview("Export now (auto)") {
    AutoExportPreview()
}

#Preview("iPhone — main") {
    CaptionedAppStoreScreenshot(
        size: .iPhone69,
        caption: "One clear intention\neach week.",
        subcaption: "Set what matters. Let the rest go.",
        content: { MockMainScreen(intention: sampleIntention) }
    )
}

#Preview("iPhone — edit") {
    CaptionedAppStoreScreenshot(
        size: .iPhone69,
        caption: "Change it any time.",
        subcaption: "No streaks. No penalty. No judgement.",
        content: { MockEditSheet(draft: "Finish the watch release.") }
    )
}

#Preview("iPhone — recall") {
    CaptionedAppStoreScreenshot(
        size: .iPhone69,
        caption: "Look back\nwithout judgement.",
        subcaption: "Every past week, searchable.",
        content: { MockRecall(items: recallItems) }
    )
}

#Preview("iPhone — widget") {
    CaptionedAppStoreScreenshot(
        size: .iPhone69,
        caption: "Always one glance away.",
        subcaption: "Home Screen widget — small and medium.",
        content: { WidgetShowcase(layout: .iPhoneSmallPlusMedium, intention: sampleIntention) }
    )
}

#Preview("iPad — main") {
    CaptionedAppStoreScreenshot(
        size: .iPad13,
        caption: "One clear intention each week.",
        subcaption: "On iPad, room for the week.",
        content: { MockMainScreen(intention: sampleIntention) }
    )
}

#Preview("Watch — app") {
    CaptionedAppStoreScreenshot(
        size: .watchUltra,
        caption: "On your wrist.",
        subcaption: nil,
        content: { MockWatchApp(intention: sampleIntention) }
    )
}

@MainActor
private func previewScale(for size: AppStoreScreenshotSize) -> CGFloat {
    switch size {
    case .iPhone69:   return 0.28
    case .iPad13:     return 0.18
    case .watchUltra: return 0.85
    }
}

#endif
