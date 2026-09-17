# gTimer Android

Initial native Android port of gTimer.

## Current milestone

- Native Android project under the same repository as the Apple app.
- Local-first timer and dose history.
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
- Add the shared add/edit/missed-dose form with location autocomplete and map pinning.
- Add the runtime location permission flow and automatic/manual dose location capture.
- Add the `https://sync.gtimer.app` auth/device-sync client.
- Add an Android home-screen widget with the same timer semantics as the Apple WidgetKit extension.
