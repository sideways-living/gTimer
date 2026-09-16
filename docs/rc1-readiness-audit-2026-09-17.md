# gTimer RC1 Readiness Audit

Date: 2026-09-17

## Result

The app is code-build ready for an internal Release Candidate 1 pass after this audit. It is not yet ready to be called an App Store release candidate until the production Apple identifiers, StoreKit subscription flow, real-device notification/location checks, and distribution signing checks are completed.

## Corrections Applied

- Moved high-traffic dose screens from broad SwiftData queries plus in-memory deleted-dose filtering to focused active/deleted queries:
  - Timer now fetches active doses only.
  - Dose map now fetches active doses only before location filtering.
  - History now uses separate active and deleted queries, preserving the include-deleted toggle without making every normal history render scan deleted rows.
  - Settings location autocomplete now absorbs only active records with coordinates.
- Replaced notification scheduling `print` output with unified OS logging.
- Added a 20 MB source-file guard before importing profile photos from disk, reducing the risk of loading oversized image files into memory.

## Validation Evidence

| Check | Result |
| --- | --- |
| iOS simulator build, `G Timer` scheme | Passed |
| macOS build, `G Timer` scheme | Passed |
| watchOS simulator build, `G Timer Watch` scheme | Passed |
| iOS static analyzer, `G Timer` scheme | Passed |
| SyncAPI tests | Passed, 10 tests |
| Android Gradle build | Passed |
| Git whitespace check | Passed |

The first macOS build attempt failed with a locked Xcode build database while iOS and macOS builds were running concurrently against the same DerivedData. It passed when rerun sequentially with a separate derived-data path.

## Remaining RC1 Gates

These are not safe to treat as complete from source/build checks alone:

- Replace Bitrig/development App Group identifiers with the registered production App Group and verify app/widget/watch entitlements.
- Complete StoreKit 2 purchase, restore, receipt/entitlement handling, and Pro subscription metadata.
- Run iOS real-device notification checks: first permission prompt, denied state, allowed state, lock-screen delivery, foreground delivery, and rescheduling after a dose.
- Run iOS real-device location checks: first permission prompt, denied state, approximate/precise state, current-location logging, and Settings reset flow.
- Run a macOS packaged installer pass: install, launch, update, uninstall, and notarization/stapling if distributing outside the Mac App Store.
- Run Instruments on representative data: Time Profiler, Allocations, Leaks, and Energy Log.
- Run App Store archive validation with the approved Apple Developer account.

## Static Findings Left Intentionally

- `Shared/AppGroup.swift` still contains the production App Group reminder because the final Apple Developer identifiers are not yet known.
- `PaywallSheet.swift` still contains the StoreKit TODO because paid Pro conversion needs real App Store product setup.
- The camera capture controller keeps the standard unavailable `init(coder:)` `fatalError` for a programmatic AppKit view controller.
- `Data(contentsOf:)` remains in profile photo file import, but it is now behind a 20 MB file-size guard and immediately passes through existing image normalization.

## RC1 Recommendation

Proceed with an internal RC1 workflow pass on this code once the current commit is built. Do not publish or submit as the App Store RC until the remaining gates above are complete, especially production identifiers, StoreKit, and real-device notification/location verification.
