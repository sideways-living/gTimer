# Future Platform Icon Assets

These assets are retained from `/Users/greenyer/Downloads/gTimer.zip` for future non-Apple versions of G Timer.

## Android

`FuturePlatformAssets/Android` contains the supplied Android launcher assets exactly as provided:

- adaptive icon XML in `res/mipmap-anydpi-v26`
- density-specific launcher foreground, background, monochrome, and combined PNGs
- `play_store_512.png`

Use these when creating the future Android project so the launcher icon and Play Store icon match the Apple app.

## Windows

`FuturePlatformAssets/Windows` contains Windows-ready copies derived from the supplied icon pack:

- `gtimer-icon.ico`
- `gtimer-icon-16.png`
- `gtimer-icon-32.png`
- `gtimer-icon-64.png`
- `gtimer-icon-128.png`
- `gtimer-icon-256.png`
- `gtimer-icon-512.png`
- `gtimer-icon-1024.png`

The `.ico` file came from the supplied web favicon. The PNG files came from the supplied macOS icon ladder and should be used as source material for MSIX, WinUI, Windows App SDK, or .NET MAUI packaging.

## Web/PWA

`FuturePlatformAssets/Web` keeps the supplied web icons and favicon. These are not part of the current Xcode build, but may be useful if a web companion or cross-platform shell is added later.
