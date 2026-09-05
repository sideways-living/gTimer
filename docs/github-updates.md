# GitHub Update Flow

gTimer can check a GitHub-hosted JSON feed at launch and alert the user when a newer build is available.

## App Configuration

The app reads `GTIMER_UPDATE_FEED_URL` from `App/Info.plist`. Leave it blank for local builds that should not check for updates.

When the GitHub repository is ready, set it to the raw GitHub URL for the tracked release feed, for example:

```text
https://raw.githubusercontent.com/OWNER/REPO/main/Dist/latest-gTimer.json
```

## Release Metadata

Each public macOS release should include:

- `Dist/latest-gTimer.json`, committed to GitHub so installed apps can read the current version.
- `gTimer-macOS-<version>-<build>-local.pkg`, uploaded as a GitHub Release asset.
- `gTimer-macOS-<version>-<build>-local.pkg.sha256.txt`, uploaded as a GitHub Release asset.

The installer package itself stays ignored by Git because binary release assets belong on GitHub Releases, not in the source tree.

## Creating A Release

1. Bump the version/build:

   ```bash
   Scripts/bump-beta-build.sh 95 0.9.5
   ```

2. Build the installer:

   ```bash
   Scripts/package-macos-installer.sh
   ```

3. Write the update feed and checksum metadata:

   ```bash
   GITHUB_REPOSITORY=OWNER/REPO Scripts/write-github-release-metadata.sh
   ```

4. Commit `Dist/latest-gTimer.json` and the `.sha256.txt` file.

5. Create the GitHub release tag, then upload the `.pkg` and `.sha256.txt` as release assets.

## Runtime Behaviour

At app launch, gTimer fetches the JSON feed if `GTIMER_UPDATE_FEED_URL` is set. If the feed version/build is newer than the installed version/build, the app shows an update alert with Download and Release notes actions.
