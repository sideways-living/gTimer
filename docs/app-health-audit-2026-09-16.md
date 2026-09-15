# gTimer App Health Audit

Date: 2026-09-16

## Scope

This audit covers the current Swift/Xcode app, widgets, watch target, Android scaffold, SyncAPI, packaging flow, and Pro conversion path. It is a source/build audit, not a full device lab pass. Real-device notification delivery, location permission prompts, StoreKit, installer signing/notarisation, and App Store archive validation still need separate end-to-end checks.

## Current Status

| Area | Result | Notes |
| --- | --- | --- |
| macOS app build | Passed | Debug build for `My Mac` succeeds with signing disabled. |
| iOS app build | Passed | Debug build for generic iOS Simulator succeeds with signing disabled. |
| Xcode static analysis | Passed | Analyzer succeeds; one print-path actor warning was fixed in this pass. |
| SyncAPI tests | Passed | Node test suite reports 10 passing tests. |
| Android build | Passed | Gradle build completes for the current Android scaffold. |
| Distribution folder | Acceptable policy | Installer packages are ignored; checksums and latest metadata remain trackable. Local `Dist/` still contains historical packages that can be pruned outside Git. |

## Fixes Applied In This Audit

### Profile Photo Storage

Imported profile images are now normalized to a maximum 512 px side length and stored as compressed JPEG data before saving to settings. This avoids keeping full-resolution camera or file-import images in app settings storage and reduces memory pressure when the profile photo is loaded.

### Print Flow Actor Isolation

The history export print function is now explicitly main-actor isolated. That matches the UIKit print controller requirement and removes the Swift concurrency warning that would become a harder problem under stricter Swift language modes.

## Performance And Memory Findings

### Data Fetch Scale

Several important screens currently fetch the full dose table into memory through SwiftData queries, then filter in view code:

- `TimerView` fetches all doses to derive the active timer and recent history.
- `HistoryView` fetches all doses for filtering/export.
- `DoseMapView` fetches all doses before filtering to located records.
- `SettingsView` fetches all dose records to absorb historical locations.

This is workable during beta and small personal logs, but it should be tightened before heavy use. The highest-value improvement is to move repeated list filtering into focused fetch descriptors or store-level helper methods:

- Timer: fetch the latest active dose and the first 30 recent display rows.
- Recent history: paginate at the data layer instead of fetching all rows.
- Map: fetch only records with latitude/longitude and page or cluster when large.
- Settings location autocomplete: build a lightweight saved-location index instead of scanning the full dose list in the settings view.

### Large SwiftUI Files

The largest files are doing too much view, state, and business-logic work in one place:

| File | Approx lines | Risk |
| --- | ---: | --- |
| `SettingsView.swift` | 2,799 | High friction for changes, high risk of unrelated UI regressions. |
| `TimerView.swift` | 904 | Timer, history, modals, navigation, and warning flows are tightly coupled. |
| `HistoryView.swift` | 906 | History list, export, print, and PDF map rendering share one file. |
| `App.swift` | 819 | App lifecycle, update checks, release notes, navigation, and commands are mixed. |
| `DoseFormSheet.swift` | 759 | The shared dose form is valuable, but should be split into input, location, map, and parser components. |

Recommended refactor order:

1. Split `SettingsView` by tab section: timer, account/privacy, sync, location, appearance/app.
2. Move history PDF/export code from `HistoryView` into an export service.
3. Move timer-state calculations from `TimerView` into a small testable model.
4. Move release/update feed models out of `App.swift`.

### Timers And Background Work

The app uses lightweight one-second timers in the main timer surfaces. That is expected for a live timer UI, but each platform should only run the ticker while the timer view/widget/watch view is visible and should invalidate cleanly on disappear. The current `TimerView` already keeps a timer handle; add a focused lifecycle test or manual QA step any time this area changes.

### UserDefaults And Widget Refresh

Settings are written directly on individual property changes. That is fine for low-frequency settings changes, but colour sliders, text fields, and quick iterative edits can produce more writes than needed. If settings editing feels laggy, batch writes on Save for high-churn fields and avoid unnecessary widget timeline reloads.

### Distribution Artifacts

The source tree is small, but local `Dist/` can grow quickly with installer packages. Keep only the latest local package plus any builds actively being tested. Git should continue tracking `Dist/latest-gTimer.json` and checksum files only; installer binaries belong in GitHub Releases.

## Feature And UX Findings

### Core Timer

The timer feature is in reasonable shape for beta: countdown/count-up, quick doses, missed dose, edit dose, recent history pagination, early-dose metadata, notifications, widgets, and the macOS layout have all been implemented in some form. The next quality gate is a real workflow pass:

- Launch fresh install.
- Complete onboarding/account choices.
- Log a normal dose.
- Log an early dose and confirm the history annotation.
- Edit amount, time, notes, tags, people, and location.
- Log missed dose with current/home/manual location.
- Verify timer, history, map, notification reschedule, widget refresh, export, and sync queue all update from the same canonical write path.

### Notifications

Notification code exists, but delivery must be verified on real iOS/macOS devices with OS notification permission states. Treat Simulator success or scheduled requests as incomplete proof. The settings page should continue offering permission status, first-use prompts, and a jump to system settings when blocked.

### Location And Maps

The app has moved toward an embedded map and shared dose form pattern. The main remaining scalability risk is map marker density and callout work. If the dose map lags with many records, add clustering or visible-region filtering before adding more marker decoration.

### Health Page

Health content should stay harm-reduction focused and localised by home/current country. Avoid wording that sounds like a recommendation to dose. Where the UI currently says "Safe to redose", consider softer language before release, such as "Minimum interval passed".

### Account, Sync, And Privacy

The local account/PIN/sync model is pointed in the right direction:

- Local-first mode remains available.
- PIN protects previous-dose viewing, not urgent dose logging.
- Sync is optional and aimed at Pro/trial use.
- Sync token and account password hash are stored through Keychain.
- Device identity is allocated when sync is enabled.

Before charging for sync, add server-side persistence, backup, recovery, rate limiting, audit logging for device revocation, and a clear data deletion path.

## Pro Conversion Findings

The app should encourage Pro without making the free app feel broken. Good Pro nudges are already emerging: sync trial, maps, exports, missed/edit dose, colour customisation, widgets, and assisted logging.

Recommended Pro model:

- Keep local timer, quick dose logging, recent history, basic settings, and health page free.
- Offer a 14-day sync trial when the user enables device sync.
- Let free users preview locked Pro screens with their own data blurred or summarized.
- Show useful Pro teasers in context: map insights from recent locations, export preview, colour theme preview, and shortcut setup preview.
- After trial expiry, keep existing local data accessible and simply pause cross-device sync.
- Avoid urgent or fear-based upgrade prompts, especially near health and emergency content.

## App Store Readiness Risks

Before App Store submission:

- Replace development App Group identifiers with registered production identifiers.
- Confirm bundle IDs for app, widget, and watch extension are nested correctly.
- Run archive validation with an approved Apple Developer account.
- Add signed/notarised macOS installer flow if distributing outside the Mac App Store.
- Complete StoreKit 2 purchases and restore purchases.
- Write privacy nutrition-label answers based on actual data collection.
- Verify location permission prompts and purpose strings on device.
- Verify notification permission prompts and delivery on device.
- Run Instruments passes: Time Profiler, Allocations, Leaks, and Energy Log.

## Recommended Next Work Blocks

1. Add data-layer pagination/focused fetches for timer, history, and map.
2. Refactor `SettingsView` into section views without changing visual behaviour.
3. Complete StoreKit 2 subscription and restore flow behind the current Pro beta gate.
4. Add SyncAPI durable production storage and auth hardening.
5. Run a real-device iOS notification/location/sync workflow pass.
6. Run a macOS installer install/update/uninstall workflow pass.
7. Add UI tests for first-run setup, dose logging, edit dose, missed dose, settings deep links, and export/print.

