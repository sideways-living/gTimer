# gTimer Android

Initial native Android port of gTimer.

## Current milestone

- Native Android project under the same repository as the Apple app.
- Local-first timer and dose history.
- Focused History search plus date, record-type, and sort filters.
- History search includes notes, tags, people, and deletion reasons.
- Existing doses can be edited, including amount, relative time, notes, tags, people, and missed-dose status.
- Dose deletion requires a reason and retains a soft-deleted audit record, with an option to include deleted doses in History.
- Tags are displayed with `#` formatting and people use a person icon, matching the cross-platform presentation contract.
- Functional missed-dose entry with amount, backdated time, notes, and a visible history marker.
- Missed-dose entry accepts tags and multiple people.
- Countdown/count-up timer semantics matching the parity document.
- Standard dose and up to four quick doses.
- Settings for dose amount, unit, interval, timer mode, notifications, Pro beta, and the Pro-only time-since-safe counter.
- Functional minimum-interval notifications with Android 13+ permission handling, rotating harm-reduction copy, rescheduling after new doses or settings changes, and reboot restoration.
- Android launcher icons reused from `FuturePlatformAssets/Android`.

## Build

```sh
cd Android
./gradlew :app:assembleDebug
```

The first run downloads the Gradle distribution and Android Gradle Plugin if they are not already cached.

## Next parity slices

- Replace the current SharedPreferences JSON store with Room or SQLDelight.
- Expand the current missed-dose entry into the shared add/edit/missed-dose form with location autocomplete and map pinning.
- Add the runtime location permission flow and automatic/manual dose location capture.
- Add the `https://sync.gtimer.app` auth/device-sync client.
- Add an Android home-screen widget with the same timer semantics as the Apple WidgetKit extension.
