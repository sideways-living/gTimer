# Future Platform Parity Plan

Last updated: 2026-09-20

## Scope

Do not start Android or Windows development from this document alone. This is a planning and handoff document so future platform work can preserve feature parity with the Swift/Xcode iOS app.

The iOS SwiftUI app is the canonical implementation. Future Android and Windows versions should match its data model, user flows, feature gates, safety wording, and privacy behavior unless this document explicitly records a platform-specific substitute.

## Current Platform Reality

| Platform | Current status | Notes |
| --- | --- | --- |
| iOS | Active canonical app | Main app builds for iPhone Simulator. Physical-device/App Store builds still need Apple Developer provisioning. |
| iOS Widget | Buildable and embedded in app | WidgetKit extension embeds with the host app, reads shared App Group timer data, supports small/medium/large widgets, and opens gTimer through `gtimer://timer`. Physical-device/App Store use still needs Apple Developer provisioning and App Group registration. |
| watchOS | Debug simulator build passing | Standalone watch app target builds, but it is not embedded in the current app-only iPhone Run path. Feature parity is partial. |
| macOS | Debug build and installer flow passing | App builds for `My Mac` with a Mac sidebar shell, responsive timer/history layout, GitHub update metadata, and package output; store readiness and Mac-specific QA still need work. |
| macOS Widget | Buildable and embedded in app | WidgetKit extension embeds in the Mac app bundle, reads the same App Group timer data, supports small/medium/large widgets, and opens gTimer through `gtimer://timer`. |
| tvOS | No target | Not configured in the Xcode project. Would be a new platform port with limited feature fit. |
| Android | Initial native project build passing | Java/Android Gradle project now lives in `Android/`. Current milestone has local-first timer, quick-dose logging, history, settings, Pro beta gate, Android icons, and functional minimum-interval notifications that survive reboot. Location, maps, widgets, full edit/missed-dose forms, billing, and SyncAPI integration remain pending parity slices. |
| Windows | Future planned | No implementation started. |

## macOS Finding

There is now an initial macOS Debug build of gTimer. Treat it as a development milestone, not a shippable Mac release.

Verified command:

```sh
xcodebuild \
  -project "G Timer.xcodeproj" \
  -scheme "G Timer" \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64,name=My Mac" \
  build
```

Previous failure fixed in the initial macOS pass:

```text
App/Views/Shared/ShareSheet.swift:2:8: error: unable to resolve module dependency: 'UIKit'
import UIKit
```

Current interpretation: the project still shares the iOS-first SwiftUI app for macOS. Platform abstractions now cover the first UIKit, keyboard, toolbar, pasteboard, device-name, share-sheet, and CoreLocation authorization blockers. The Mac app now uses sidebar navigation, a Mac-sized main window, and two timer layouts: compact windows show the timer above dose buttons, while wider windows add recent history on the right. It still needs proper Mac UX review and packaging decisions.

Recommended short-term action: keep day-to-day iPhone development on iPhone Simulator, and run a macOS Debug build after shared UI/platform changes.

Recommended future macOS action: decide whether the first Mac release should remain a shared SwiftUI Mac app or split into an explicit Mac target with Mac-specific layout, window sizing, menu commands, and store metadata.

## watchOS Finding

There is a buildable standalone Apple Watch app target.

Verified command:

```sh
xcodebuild \
  -project "G Timer.xcodeproj" \
  -scheme "G Timer Watch" \
  -configuration Debug \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5" \
  build
```

Current interpretation: watchOS should stay as a companion glance/control surface, not a full parity target. The watch can show current timer state from shared data, but phone-only flows such as full settings, export, detailed history, maps, and profile setup should remain on iPhone/macOS unless a deliberate watch UX is designed.

## tvOS Finding

There is no tvOS target in the current Xcode project.

tvOS is a poor fit for the core dose-logging workflow because Apple TV is usually shared, not personal, and lacks the same notification, location, Health-adjacent, and quick private input expectations as iPhone/Watch/Mac. If tvOS is ever pursued, treat it as a dashboard/view-only companion unless there is a strong product reason to support logging on a television.

## Canonical iOS Feature Set

Future Android and Windows versions should match these features:

| Area | Required behavior |
| --- | --- |
| Timer | Start from logged dose time; support countdown and count-up modes; apply configured interval; show active/inactive state; keep six-hour active window. Pro users can optionally show a second status timer counting up from `00:00:00` once the minimum interval has passed. |
| Countdown mode | Display remaining time; arc starts fully coloured and empties from the right as time elapses. |
| Count-up mode | Display elapsed time; arc starts empty and fills from the left as time elapses. |
| Dose logging | Standard-dose button, 0-4 quick-dose buttons, custom amount, early-log warning before interval has elapsed. A quick dose is committed and shown in history immediately, then opens a 30-second confirmation editor while location resolves in the background. The editor displays the resolved location when available, permits location, hashtag, and people amendments, saves and closes on Submit, and automatically saves and closes at 30 seconds. Custom/add-dose entry uses the shared dose form pattern below, including notes, hashtag-style tags, and remembered people. |
| Assisted logging | Pro-gated Siri, Shortcuts, deep-link, and trusted automation logging. Spoken commands should create the same canonical dose records as the app UI, including amount, unit, optional time, missed-dose detection for backdated times, spoken/saved/current location, hashtag-style tags, people, notes, early-dose metadata, notification rescheduling, widget refresh, and sync queuing. |
| Quick doses | Settings use four individual optional values. Main timer shows 4, 3, 2, 1, or setup-link states depending on saved values. |
| History | Reverse chronological dose records; search by tags, people, notes, locations, deletion reasons, amounts, and device; filter by date range, record type, and amount; sort by time or amount; delete; delete all; free mode limits visible history; Pro unlocks full history. Deleted dose records are retained with `deletedAt` and a user-entered deletion reason, and History has a toggle for including or hiding deleted records. |
| Missed doses | Pro-gated backdated dose entry using the shared dose form pattern below. |
| Edit dose | Pro-gated correction of amount, time, notes, tags, people, and location fields using the shared dose form pattern below. |
| Export | Pro-gated CSV export; warn clearly before exporting location data. |
| Health content | Harm-reduction information and emergency guidance. Avoid medical certainty. |
| Settings | Dose defaults, unit, substance, interval presets/custom interval, quick doses, timer mode, time format, notifications, device name, Pro profile, and location options. |
| Pro | Current app uses free beta activation. Future store payments are a separate product decision. |
| Account security | Keep account UI email-first and hide infrastructure URLs and tokens. Signed-in views show the user name and email, allow an authenticated password change, and identify active devices with macOS, iOS/iPadOS, Android, Windows, or web icons. Privacy PIN creation and unlocking use an on-screen numeric keypad. SyncAPI now has tested server foundations for encrypted authenticator-app TOTP secrets, one-time recovery codes, passkey challenge verification, credential listing, and revocation. Keep setup controls inactive until native ceremonies, associated-domain files, recovery-code presentation, and end-to-end deployment tests are complete. |
| Notifications | Optional local reminder when the configured timing interval elapses. Notification copy must not imply medical safety. Show `gTimer` as the top notification title, followed by `Your minimum time between doses has passed`, then one rotating harm-reduction message. The pending reminder should always be derived from the most recent active dose, should reschedule after edits/deletes/sync changes, and should still present while the app is foregrounded where the platform allows it. |
| Location | Pro-gated optional location recording; request native location permission when location logging is first used, show current permission status in Settings, and provide a system-settings recovery action when permission is blocked. Quick logging saves immediately, then enriches the record in the background. If the captured point is within 150 metres of Home or a saved/previously used location, prefer the recognised place (frequent history names before one-off names) over a newly reverse-geocoded street address. Preserve the original GPS accuracy and capture time when snapping to the recognised place. The current setting named "Show approximate location" rounds display only, not saved coordinates. |
| Map/insights | Pro-gated dose map and location summary behavior. Map supports the same text, date-range, record-type, amount, and sort filters as History, and recalculates its summary from visible markers. When visible in navigation, Map sits between History and Health. Marker details open as anchored overlays so the dose marker remains fixed as the focal point, with the callout pointer adapting near map edges. |
| Widgets | Companion widgets show current timer status, last dose amount/time, safe interval progress, and an open-app action. Widgets must match countdown/count-up visual semantics. Widgets should not directly write dose history unless the platform implementation writes through the canonical dose store and triggers the same notification/update flow. |
| Export/print | Pro-gated export window supports date range, field selection, location/map inclusion, PDF export, and print output. When map output is selected, include a full-page rendered visual map with dose markers. Desktop platforms should expose keyboard commands for these flows. |

### Shared Dose Form Pattern

Add dose, missed dose, and edit dose should present the same core flow on every platform:

- Desktop and large tablet layouts: wide modal or window, close button in the top-right of the header row, input column on the left, interactive local map on the right.
- Phone layouts: same controls in a scrollable single-column sheet, with the map below the input fields.
- Input column: amount and date/time controls together at the top, followed by compact notes, then a full-width location text field for address, suburb, venue, hotel, or typed place name.
- Tags and people: split the space above notes into hashtag-style tags and remembered people. Tags should normalize to `#tag` form and support searches such as `#hookup`. People entries should autocomplete from names previously used by the signed-in/local user.
- Location field: autocomplete from saved user/history locations and platform geocoder/place search; bias search near saved home location and current location when available.
- Location shortcuts: current-location and home-location icon buttons at the end of the location field, with accessible labels/tooltips.
- Location permission: choosing current location should request native permission if it has not already been requested, and should explain when OS settings block access.
- Map: pan/zoom, tap/click to drop a pin, reverse geocode the pin, and fill the location text field from the selected pin.
- Submit button: label must match the flow, for example `Log Dose`, `Save Changes`, or `Log Missed Dose`.

## Data Model Parity

All future platforms should preserve these fields:

| Field | Type | Notes |
| --- | --- | --- |
| `id` | UUID/string | Stable unique record id. |
| `amount` | Decimal/double | Dose amount. |
| `unit` | String | `ml`, `g`, or `mg`. |
| `time` | Date/time | Actual dose time; missed doses may be backdated. |
| `deviceName` | String | Device label at logging time. |
| `notes` | String | Optional free text. |
| `tags` | String array | Optional hashtag-style tokens, normalized to `#tag`. Tags may be globally named but history/search results must remain scoped to the current user unless explicit dose sharing is later implemented. |
| `people` | String array | Optional remembered person names for autocomplete and filtering. |
| `missed` | Boolean | True for missed-dose flow. |
| `edited` | Boolean | True after a manual edit. |
| `latitude` | Decimal/double nullable | Optional saved latitude. |
| `longitude` | Decimal/double nullable | Optional saved longitude. |
| `locationName` | String nullable | Optional place label. |
| `locationAccuracyMeters` | Decimal/double nullable | Optional accuracy metadata. |
| `locationCapturedAt` | Date/time nullable | Optional location capture time. |
| `locationSource` | String nullable | `automatic`, `current`, `manual`, `home-fallback`, `none`; nil should be treated as `none`. |
| `deletedAt` | Date/time nullable | Soft-delete tombstone timestamp for sync and deletion audit history. |
| `deletionReason` | String nullable | User-entered deletion reason, for example duplicate recording. Preserve with tombstones and include in history search/export when deleted records are shown. |

CSV exports/imports should use the same field names unless a migration map is explicitly documented.

## Settings Parity

| Setting | Current iOS behavior | Future parity requirement |
| --- | --- | --- |
| Standard dose | Defaults to `1.5` | Same default and positive-number validation. |
| Unit | `ml`, `g`, `mg` | Same values. |
| Substance | `GHB`, `GBL` | Same values unless product scope changes. |
| Timing interval | Presets 60, 90, 120 plus custom minutes | Same defaults and validation. |
| Quick amounts | Four optional boxes | Store only positive entered values; blank boxes remove buttons. |
| Notifications | Off by default | Native opt-in permission flow. |
| Timer mode | Countdown/count-up | Match display and arc behavior exactly. |
| Time format | Setting exists | Preserve until product decision removes or uses it consistently. |
| Time since safe | Pro-gated and off by default | When enabled, show an elapsed timer under the safe-to-redose status only after the configured minimum interval has passed. |
| Assisted dose logging | Pro-gated and off by default | Controls whether Siri/assistant/automation logging is allowed. Separate settings control current-location capture, saved/recent-place matching, and whether the spoken phrase is saved into notes. |
| Device name | Editable | Same semantics. |
| Pro beta | Local entitlement currently | Replace only through a cross-platform entitlement decision. |
| Profile | Pro-gated display name/photo | Same gate or documented store-specific equivalent. |
| Location attach | Pro-gated and off by default | Native permission prompt when first used; Settings must show permission status and offer recheck/system-settings recovery. |
| Show approximate location | Display rounding only | If future privacy-preserving storage is added, update all platforms together. |

## Apple Companion Platform Notes

WidgetKit:

- iOS and macOS widgets read `SharedDoseData` from the App Group container.
- Widgets are display/open-app surfaces, not autonomous dose writers.
- Support small, medium, and large widget families.
- Match countdown/count-up gauge semantics: countdown starts full and empties; count-up starts empty and fills.
- Reload timelines after dose records or timer settings change.

macOS:

- Provide menu commands for opening gTimer, History, Map, Health, Settings, and gTimer Pro. Map should appear between History and Health where it is visible.
- Provide menu commands for new dose, export history to PDF, print history, and quit with confirmation.
- Keep desktop export/print controls aligned with future Windows desktop behavior.

watchOS:

- Keep as a companion timer/status surface.
- Match countdown/count-up semantics with the iOS timer.
- Read shared dose state from the iPhone app where possible.
- Avoid adding full data-management workflows until the iOS/macOS data model is stable.

tvOS:

- No current implementation.
- Do not claim parity unless a tvOS target exists and has a documented product scope.
- Recommended scope, if added later: read-only timer display, basic status, and possibly educational health content.
- Avoid location capture, private dose entry, profile setup, export, and Pro account flows on tvOS unless explicitly approved as product scope.

## Android Implementation Notes

Current Android milestone:

- Project path: `Android/`.
- Package/application id: `app.gtimer.android`.
- Current build artifact: debug APK from `./gradlew :app:assembleDebug`.
- Storage: temporary `SharedPreferences` JSON store, to be replaced with Room or SQLDelight before broad testing.
- Implemented screens: gTimer, filterable History, Map placeholder, Health, Settings, and gTimer Pro.
- Implemented timer behavior: standard dose, configured quick doses, early-dose warning/history note, countdown/count-up display, and Pro-gated time-since-safe status counter.
- Implemented history behavior: text search, date/type/sort controls, regular/missed/early filtering, and functional backdated missed-dose entry with notes.
- Implemented notifications: Android 13+ runtime permission request, notification channel, rotating harm-reduction messages, cancellation/rescheduling from the latest dose, and reboot restoration.

Recommended stack:

- Kotlin.
- Jetpack Compose.
- Room or SQLDelight for local dose storage.
- DataStore for settings.
- WorkManager/AlarmManager for interval notifications.
- Google Maps or Mapbox for maps.
- Glance/AppWidget for home-screen widget parity.

Android-specific substitutions:

- Replace iOS local notifications with Android notification channels and runtime notification permission.
- Replace iOS location permission flow with Android foreground location permission.
- Replace WidgetKit with Android Glance/AppWidget widgets that show timer status, last dose amount/time, safe interval progress, and open the app to the timer. Direct widget logging is only parity-complete if it writes the canonical history record and triggers the same update/notification flow.
- Replace Siri/App Shortcuts with Android App Actions, Shortcuts, widgets, or a trusted assistant integration that calls the same local assisted-dose command parser before writing the canonical dose record.
- On keyboard-capable Android devices, expose equivalent shortcuts where practical. On touch-only devices, preserve the same export options through visible controls rather than relying on keyboard commands.
- If cross-platform sync is needed, do not use an Android-only sync backend unless the product decision explicitly allows it.
- Use the retained launcher and Play Store icon assets in `FuturePlatformAssets/Android` so the Android release matches the Apple app icon.

## Windows Implementation Notes

Recommended stack:

- WinUI 3, Windows App SDK, or .NET MAUI if shared C# code is preferred.
- SQLite for dose storage.
- Windows app settings or SQLite-backed preferences.
- Windows notifications for interval reminders.
- Native map control or web map view for dose map.
- Windows Widgets, tray, taskbar, or live-tile equivalent for timer widget parity.

Windows-specific substitutions:

- If Windows Widgets are not suitable, document a tray/live-tile/taskbar equivalent before claiming widget parity. The equivalent must show timer status, last dose amount/time, safe interval progress, and open the app to the timer.
- Direct widget/tray logging is only parity-complete if it writes the canonical history record and triggers the same update/notification flow.
- Provide a trusted assistant/automation route, such as a protocol handler, command-line helper, Power Automate action, or local API, that uses the same assisted-dose command parser before writing the canonical dose record.
- Match the macOS desktop command set with Windows menu/ribbon/keyboard equivalents: open app sections, new dose, export PDF, print, settings, and quit confirmation.
- Location capture depends on Windows device/location permissions and hardware availability.
- Do not silently omit Pro, export, location, or history behavior; mark unsupported items as product decisions.
- Use the retained Windows icon source files in `FuturePlatformAssets/Windows` for `.ico`, MSIX, Start menu, taskbar, and store packaging.

## Retained Future Platform Assets

Non-Apple icon assets from the September 2026 gTimer icon pack are checked in under `FuturePlatformAssets`.

- `FuturePlatformAssets/Android` preserves the supplied Android adaptive launcher, density-specific launcher PNGs, monochrome icon, and Play Store 512 image.
- `FuturePlatformAssets/Windows` keeps a Windows `.ico` plus PNG source sizes derived from the supplied icon pack.
- `FuturePlatformAssets/Web` keeps the supplied favicon and web/PWA PNGs for future web or shell builds.

## Sync Decision

The current Apple implementation can use Apple-only storage patterns. Android and Windows will not get parity from iCloud alone.

Recommended long-term direction: build a cross-platform sync backend for dose history, settings, Pro entitlements, profile data, and saved locations. Apple-only iCloud sync can be useful for iPhone, iPad, Mac, Watch, and Widget handoff, but it must not be treated as the parity solution for Android or Windows.

Current beta direction: `SyncAPI` is the chosen custom API starting point and is deployed at `https://sync.gtimer.app`. App version 0.9.17 adds opt-in Apple client support for dose-history sync against this API. App version 0.9.19 adds beta email/password accounts with per-device tokens and device removal. App version 0.9.20 makes account sync optional, positions it as a gTimer Pro benefit, and adds a 14-day free device-sync trial. App version 0.9.24 separates local account setup from sync-device registration: first launch collects a local name, email address, and password for data protection and optional PIN recovery, while a sync device id is only created when the user starts a sync trial or has gTimer Pro and explicitly registers that install for sync. App version 0.9.26 adds synced dose tags and people fields for future cross-device search parity. App version 0.9.27 adds the Apple App Intents layer and local `gtimer://log?...` deep link for Pro-gated assisted dose logging. Android and Windows should expose equivalent assistant/automation entry points through the same normalized command contract: parse spoken amount, unit, time, location phrase, tags, people, notes, and missed-dose intent; resolve location against saved/recent/home/current context; then write one normal local dose record and sync it through `SyncAPI`.

Before Android or Windows implementation begins, keep this decision unless there is an explicit product/security review that replaces it:

1. Cross-platform sync backend for all platforms.
2. Apple-only sync for Apple devices only as a temporary fallback.
3. No sync for a store release only if the API is not production-ready.

### Preferred Cross-Platform Sync Model

Use a small account-backed API with an encrypted local store on every device:

- Local-first operation: the app must keep logging doses offline and sync when a connection returns.
- Local account setup: first launch should make local-only operation clear while still collecting the user's name, email address, and password into secure local storage for data protection and optional PIN recovery. This must not create a server sync device by itself.
- Optional history PIN: all platforms should offer a basic numeric PIN that locks previous-dose surfaces such as History and Map, while current dose recording remains available without unlocking. PIN reset uses the local account password tied to the saved email address.
- Per-user account identity: sync records belong to the signed-in user, not the device.
- Per-device access: each signed-in device receives its own token so a lost or retired device can be removed without resetting every other device. A stable per-install device key should only be generated at sync registration time, and repeated registration from the same app install must reuse the same active device record instead of creating duplicates.
- Entitlement: device sync is a Pro entitlement. New sync accounts may receive a short free trial, but all platforms must enforce the same trial expiry and paid-access rules.
- Stable record ids: every dose, settings row, saved location, and profile record needs a stable id generated before upload.
- Changed-at timestamps: every synced object should carry `createdAt`, `updatedAt`, and `deletedAt` for conflict handling.
- Soft deletes: deleting a dose should sync as a tombstone first, then be compacted later.
- Conflict policy: dose history should preserve both conflicting edits where data loss is possible, while settings can use last-write-wins with visible review if an important setting changes on another device.
- Privacy: location coordinates and notes are sensitive data. If server sync is used, design for encryption at rest, transport security, export/delete account controls, and minimal logging.
- Migration: local Apple data is the source of truth until sync is enabled. First sync uploads existing dose records, then pulls records from the server.

Recommended backend options to assess before implementation:

- CloudKit/iCloud only: fastest for Apple platforms, not suitable for Android/Windows parity.
- Firebase or Supabase: practical cross-platform account, database, and offline-sync foundation, but requires careful health-data privacy review.
- Custom API plus Postgres: strongest control over privacy, auditability, exports, and future entitlement logic, but more implementation and operations work.

For future feature parity, do not ship two independent sync systems. If Apple iCloud sync ships first, label Android/Windows sync as pending until the shared backend exists or a deliberate local-only product decision is recorded.

## Feature Gate Parity

Free:

- Current dose logging.
- Standard dose and quick-dose buttons.
- Custom amount logging.
- Current timer.
- Recent history.
- Health content.
- Basic settings.
- 14-day device-sync trial for new sync accounts.

Pro:

- Full history.
- Edit dose records.
- CSV export.
- Missed-dose logging.
- Location capture.
- Dose map.
- Location insights.
- Profile.
- Device sync after the free trial.

Do not move features between Free and Pro on one platform only.

## Future Readiness Checklist

Before Android work starts:

- Confirm sync approach.
- Confirm Pro payment/entitlement approach.
- Freeze CSV schema.
- Create Android-specific QA checklist from this document.

Before Windows work starts:

- Confirm whether Windows is desktop-first or tablet/touch-first.
- Confirm widget/tray expectation.
- Confirm location capture requirements.
- Create Windows-specific QA checklist from this document.

Before macOS release work continues:

- Decide whether macOS is a native Mac app, Catalyst app, or iPad-on-Mac support.
- Review and refine Mac-specific navigation, window sizing, share/export, profile photo, map, notification, and location permission flows.
- Decide whether WidgetKit/watchOS features remain Apple-platform-only.
- Keep explicit macOS build validation in the release checklist.

Before watchOS release work continues:

- Decide whether it is standalone, companion-only, or both.
- Verify app-group sharing and installation through the iPhone host once Developer provisioning is available.
- Match the timer arc/countdown behavior with iOS.
- Define which Pro features are intentionally unavailable on watchOS.

Before tvOS work starts:

- Confirm whether tvOS has a real user workflow or should remain out of scope.
- Create a tvOS target only after defining a limited parity scope.
- Document privacy expectations for shared-screen use.

## Update Rule

Any iOS feature change that affects future Android, Windows, or macOS behavior should update this document in the same commit.
