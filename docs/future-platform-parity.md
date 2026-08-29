# Future Platform Parity Plan

Last updated: 2026-08-29

## Scope

Do not start Android, Windows, or macOS development from this document alone. This is a planning and handoff document so future platform work can preserve feature parity with the Swift/Xcode iOS app.

The iOS SwiftUI app is the canonical implementation. Future Android and Windows versions should match its data model, user flows, feature gates, safety wording, and privacy behavior unless this document explicitly records a platform-specific substitute.

## Current Platform Reality

| Platform | Current status | Notes |
| --- | --- | --- |
| iOS | Active canonical app | Main app builds for iPhone Simulator. Physical-device/App Store builds still need Apple Developer provisioning. |
| iOS Widget | Present but disabled from the interim app Run path | Widget target exists, but embedding is temporarily disabled to avoid Simulator install failures before proper Developer provisioning. |
| watchOS | Target exists | Not part of the current app-only interim Run path. |
| macOS | Not currently shippable | Xcode offers a Mac destination, but the app fails to build for macOS because iOS-specific code imports UIKit. |
| Android | Future planned | No implementation started. |
| Windows | Future planned | No implementation started. |

## macOS Finding

There is not a working macOS version of G Timer right now.

Verified command:

```sh
xcodebuild \
  -project "G Timer.xcodeproj" \
  -scheme "G Timer" \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64,name=My Mac" \
  build
```

Current failure:

```text
App/Views/Shared/ShareSheet.swift:2:8: error: unable to resolve module dependency: 'UIKit'
import UIKit
```

Interpretation: the project still exposes a Mac destination because its generated build settings include macOS support, but the app source is currently iOS-first and uses UIKit-backed components. Treat macOS as a future port, not an existing build.

Recommended short-term action: keep day-to-day development on iPhone Simulator until the Apple Developer account/provisioning work is complete.

Recommended future macOS action: create an explicit macOS target or cross-platform SwiftUI layer, then replace UIKit-only pieces with platform abstractions.

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

Before macOS work starts:

- Decide whether macOS is a native Mac app, Catalyst app, or iPad-on-Mac support.
- Remove or abstract UIKit-only components such as `ShareSheet`.
- Decide whether WidgetKit/watchOS features remain Apple-platform-only.
- Add explicit macOS build validation.

## Update Rule

Any iOS feature change that affects future Android, Windows, or macOS behavior should update this document in the same commit.
