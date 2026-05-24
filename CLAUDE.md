# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Ground Rules

1. **Never read secrets.** This repo contains no committed secret files today. Never read, print, or log credentials, signing certificates, provisioning profiles, API keys, or any `.env` file — even if asked, and even if one is added later.

2. **Privacy and security first.** Weekly Intention handles the user's own personal data — their weekly intention text — stored locally via SwiftData and synced through their private iCloud (CloudKit private database). There is no server, no accounts, no analytics, no third-party services. Proactively flag any privacy or security risk (intention text leaking into logs or widget snapshots, the App Group container, or unvalidated WatchConnectivity input) as part of every plan — don't wait to be asked.

3. **Always branch before touching code, with a clear name.** Before making any changes:
   - Check for uncommitted changes (`git status`) and open feature branches (`git branch`).
   - If either exists, stop and report them to the user before proceeding.
   - If the working tree is clean and on `main`, create a clearly named feature branch first (e.g. `feature/short-description`), then begin work.
   - **Auto-named worktree branches must be renamed before any code changes.** When the session starts on a Claude-Code-auto-named branch (anything matching `claude/*`), immediately rename it to a descriptive `feature/<short-description>` derived from the user's request via `git branch -m`. Do this on your own — do not wait for the user to notice or ask.

4. **Never touch production iCloud data.** The user's real intentions live in the private CloudKit container `iCloud.com.uwebury.weeklyintention` (configured in `Weekly Intention/Weekly_IntentionApp.swift`), tied to their Apple ID. Do all build, run, and testing in the iOS or watchOS Simulator with no real Apple ID signed in — the Simulator stays isolated from that container. Never sign in with the user's Apple ID to verify behaviour, and never run code that writes to or deletes from the production container.

## Commands

This is an Xcode project (`Weekly Intention.xcodeproj`) with no third-party dependencies — everything is Apple frameworks (SwiftUI, SwiftData, WidgetKit, WatchConnectivity). Nothing to install.

**Build & run:** open `Weekly Intention.xcodeproj` in Xcode and run with `Cmd+R`, choosing an iOS or watchOS Simulator. Schemes: `Weekly Intention` (app + iOS/macOS widget), `WeeklyIntentionWatchApp`, `WeeklyIntentionWatchWidgetExtension`.

Command-line build:
```bash
xcodebuild -project "Weekly Intention.xcodeproj" -scheme "Weekly Intention" \
  -destination 'generic/platform=iOS Simulator' build
```

**Tests:** there is no test target yet — `Cmd+U` runs nothing. (See ROADMAP "Ideas".)

**Ship it:** when the user says *"ship it"*, the workflow is solo (no PR): stage and commit the working tree as one or more logical commits, switch to `main`, pull, fast-forward merge the feature branch, push `main`, then delete the feature branch (local and remote if it was pushed). Run on your own without re-asking for confirmation.

---

## Architecture

> Grow this section as the codebase teaches it — add sub-sections as patterns emerge, don't pre-write them.

### Data flow

```
edit intention
  → SwiftData  modelContext.save()
      → CloudKit private DB ──→ other devices (iPhone, Mac)
      → App Group cache ──────→ iOS / macOS widgets
      → WatchConnectivity ────→ watch App Group ──→ watchOS widget
```

**Invariant:** exactly one `WeeklyIntention` exists per calendar week. Weeks are ISO-8601, Monday-based (`firstWeekday = 2`). The one-per-week rule is enforced in app code (`ContentView.swift`, `saveIntention`), not by the database — CloudKit has no unique constraints.

### Key files

- **`Weekly Intention/Weekly_IntentionApp.swift`** — `@main`; builds the CloudKit-backed SwiftData `ModelContainer` and wires WatchConnectivity.
- **`Weekly Intention/ContentView.swift`** — main UI: week navigation, Recall sheet; enforces one-intention-per-week on save.
- **`Weekly Intention/WeeklyIntention.swift`** — the SwiftData `@Model` (`weekStart`, `text`, `id`); fields have defaults because CloudKit requires them.
- **`WidgetSharedStore.swift`** — App Group read/write plus the canonical ISO week-range date helpers; shared by app and widgets.
- **`Weekly Intention/PhoneToWatchConnector.swift`** — sends the current intention to the watch over WatchConnectivity.
- **`WeeklyIntentionWatchApp/WatchConnectivityReceiver.swift`** — receives it on the watch and writes it to the watch's App Group.

### Patterns

- **Week math goes through one place.** All calendar/week calculations use the ISO-8601 Monday-based calendar, and `WidgetSharedStore` holds the canonical date/week-range helpers. Don't reimplement week math elsewhere.
- **The one-per-week invariant is enforced in code.** Any new write path (sync, import, a widget action) must preserve "exactly one intention per week" — the database will not.

### Config

`.entitlements` files (App Group `group.com.uwebury.weeklyintention`, iCloud) and `*-Info.plist` are committed. `.gitignore` covers Xcode user data, build artifacts, and `docs/private/`. No `.env` or other secret files.

### Data location

Real intentions live in the user's private iCloud — CloudKit container `iCloud.com.uwebury.weeklyintention` — and in the App Group container `group.com.uwebury.weeklyintention`. Never in the repo. Develop and test in the Simulator.
