# TimeTracker

A Liquid Glass time tracker for macOS: start a timer for a project, or add a recording by hand, then review your recordings as a list or a calendar and export them as a PDF.

**[Download TimeTracker.dmg](https://github.com/breidenbach0/time-tracker/releases/latest/download/TimeTracker.dmg)** from the [latest release](https://github.com/breidenbach0/time-tracker/releases/latest).

## Install

1. **Download** [TimeTracker.dmg](https://github.com/breidenbach0/time-tracker/releases/latest/download/TimeTracker.dmg).
2. **Open the disk image** and drag **TimeTracker** onto the **Applications** folder next to it.
3. **Open TimeTracker.** It isn't notarized by Apple, so macOS asks first. If it says it couldn't verify TimeTracker, click **Done**, open **System Settings › Privacy & Security**, scroll down and click **Open Anyway**. You only do this once, and macOS still checks TimeTracker for malware on the way.

Needs macOS 13 Ventura or later, on Apple silicon or Intel. Liquid Glass needs macOS 26 or later; earlier versions get a frosted blur instead.

## Update

TimeTracker looks for a new version on GitHub when it starts, and once a day while it's open. When there is one, a card at the bottom of the window offers **Install Update**: TimeTracker downloads it, checks that it's signed with TimeTracker's release key, puts it in place of itself and starts again. A recording that's running keeps going. **TimeTracker › Check for Updates…** (or **Settings › Updates › Check Now**) looks right away; turn off **Check for Updates Automatically** to stop the daily look. Installing needs TimeTracker in a folder you can write to, such as Applications.

Your recordings live in `~/Documents/TimeTracker` and aren't touched by updates.

## Build from source

You need Xcode 15 or later. The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`) after adding or removing files.

```bash
git clone https://github.com/breidenbach0/time-tracker.git
cd time-tracker
open TimeTracker.xcodeproj
```

`xcodebuild -project TimeTracker.xcodeproj -scheme TimeTracker -destination platform=macOS test` runs the tests, including updating TimeTracker from a stand-in release.

## Releasing

1. Bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in `project.yml`, then run `xcodegen generate`. The updater only installs a release whose app has exactly the version its tag says.
2. Run `scripts/package-macos-dmg.sh`. It builds `dist/TimeTracker.dmg`, the download, and `dist/TimeTracker.zip`, which the in-app updater installs, and signs the zip into `dist/TimeTracker.zip.sig`. macOS asks you to allow the use of the signing key.
3. Commit, push to `main`, and attach all three files to a release tagged `vX.Y.Z` and marked latest:
   ```bash
   gh release create vX.Y.Z dist/TimeTracker.dmg dist/TimeTracker.zip dist/TimeTracker.zip.sig --target main --latest
   ```

Updates are signed with an Ed25519 key kept in the maintainer's login Keychain (item "TimeTracker update signing key"); macOS asks before each use. `scripts/sign-update.swift --create-key` made it once and printed its public half, which is `UpdateSource.releaseKey` in `TimeTracker/Services/Updater.swift`. The updater refuses any update not signed with it, so someone who only gets into the GitHub account can't push one. Never replace the key: released copies only accept this one. `UNSIGNED=1 scripts/package-macos-dmg.sh` builds without signing, for builds that won't be released.
