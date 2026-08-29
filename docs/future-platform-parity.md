# Future Platform Parity Plan

Last updated: 2026-08-29

## Scope

Do not start Android or Windows development from this document alone. This is a planning and handoff document so future platform work can preserve feature parity with the Swift/Xcode iOS app.

The iOS SwiftUI app is the canonical implementation. Future Android and Windows versions should match its data model, user flows, feature gates, safety wording, and privacy behavior unless this document explicitly records a platform-specific substitute.

## Current Platform Reality

| Platform | Current status | Notes |
| --- | --- | --- |
| iOS | Active canonical app | Main app builds for iPhone Simulator. Physical-device/App Store builds still need Apple Developer provisioning. |
| iOS Widget | Present but disabled from the interim app Run path | Widget target exists, but embedding is temporarily disabled to avoid Simulator install failures before proper Developer provisioning. |
| watchOS | Debug simulator build passing | Standalone watch app target builds, but it is not embedded in the current app-only iPhone Run path. Feature parity is partial. |
| macOS | Initial Debug build passing | App builds for `My Mac` with a Mac sidebar shell and responsive timer/history layout; packaging, store readiness, and Mac-specific QA still need work. |
| tvOS | No target | Not configured in the Xcode project. Would be a new platform port with limited feature fit. |
| Android | Future planned | No implementation started. |
| Windows | Future planned | No implementation started. |

## macOS Finding

There is now an initial macOS Debug build of G Timer. Treat it as a development milestone, not a shippable Mac release.

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
| Timer | Start from logged dose time; support countdown and count-up modes; apply configured interval; show active/inactive state; keep six-hour active window. |
| Countdown mode | Display remaining time; arc starts fully coloured and empties from the right as time elapses. |
| Count-up mode | Display elapsed time; arc starts empty and fills from the left as time elapses. |
| Dose logging | Standard-dose button, 0-4 quick-dose buttons, custom amount, early-log warning before interval has elapsed. |
| Quick doses | Settings use four individual optional values. Main timer shows 4, 3, 2, 1, or setup-link states depending on saved values. |
| History | Reverse chronological dose records; delete; delete all; free mode limits visible history; Pro unlocks full history. |
| Missed doses | Pro-gated backdated dose entry with optional notes and optional location. |
| Edit dose | Pro-gated correction of amount, time, notes, and location fields. |
| Export | Pro-gated CSV export; warn clearly before exporting location data. |
| Health content | Harm-reduction information and emergency guidance. Avoid medical certainty. |
| Settings | Dose defaults, unit, substance, interval presets/custom interval, quick doses, timer mode, time format, notifications, device name, Pro profile, and location options. |
| Pro | Current app uses free beta activation. Future store payments are a separate product decision. |
| Notifications | Optional local reminder when the configured timing interval elapses. Notification copy must not imply medical safety. |
| Location | Pro-gated optional location recording; current setting named "Show approximate location" rounds display only, not saved coordinates. |
| Map/insights | Pro-gated dose map and location summary behavior. |

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
| `missed` | Boolean | True for missed-dose flow. |
| `edited` | Boolean | True after a manual edit. |
| `latitude` | Decimal/double nullable | Optional saved latitude. |
| `longitude` | Decimal/double nullable | Optional saved longitude. |
| `locationName` | String nullable | Optional place label. |
| `locationAccuracyMeters` | Decimal/double nullable | Optional accuracy metadata. |
| `locationCapturedAt` | Date/time nullable | Optional location capture time. |
| `locationSource` | String nullable | `automatic`, `manual`, `none`; nil should be treated as `none`. |

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
| Device name | Editable | Same semantics. |
| Pro beta | Local entitlement currently | Replace only through a cross-platform entitlement decision. |
| Profile | Pro-gated display name/photo | Same gate or documented store-specific equivalent. |
| Location attach | Pro-gated and off by default | Native permission prompt. |
| Show approximate location | Display rounding only | If future privacy-preserving storage is added, update all platforms together. |

## Apple Companion Platform Notes

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
- Replace WidgetKit with Android widgets.
- If cross-platform sync is needed, do not use an Android-only sync backend unless the product decision explicitly allows it.

## Windows Implementation Notes

Recommended stack:

- WinUI 3, Windows App SDK, or .NET MAUI if shared C# code is preferred.
- SQLite for dose storage.
- Windows app settings or SQLite-backed preferences.
- Windows notifications for interval reminders.
- Native map control or web map view for dose map.

Windows-specific substitutions:

- If Windows Widgets are not suitable, document a tray/live-tile/taskbar equivalent before claiming widget parity.
- Location capture depends on Windows device/location permissions and hardware availability.
- Do not silently omit Pro, export, location, or history behavior; mark unsupported items as product decisions.

## Sync Decision

The current Apple implementation can use Apple-only storage patterns. Android and Windows will not get parity from iCloud alone.

Before Android or Windows implementation begins, choose one:

1. Apple-only sync for iOS/watchOS/widget, with Android/Windows local-only.
2. Cross-platform sync backend for all platforms.
3. No sync for any store release until a later version.

Record the decision here before writing platform code.

## Feature Gate Parity

Free:

- Current dose logging.
- Standard dose and quick-dose buttons.
- Custom amount logging.
- Current timer.
- Recent history.
- Health content.
- Basic settings.

Pro:

- Full history.
- Edit dose records.
- CSV export.
- Missed-dose logging.
- Location capture.
- Dose map.
- Location insights.
- Profile.
- Any future sync entitlement if product decides sync is Pro.

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
