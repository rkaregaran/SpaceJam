# SpaceJam

**Your desktops. At your speed.**

Choose how quickly your Mac slides between desktops. SpaceJam works with
**Control–Left/Right** and mouse buttons mapped to those shortcuts.

![SpaceJam settings](docs/images/settings.png)

## Install

**Apple silicon · macOS 27 · at least two ordinary desktops**

Downloads are Developer ID signed and notarized by Apple.

1. [Download the latest DMG](https://github.com/rkaregaran/SpaceJam/releases/latest).
2. Open it and drag **SpaceJam** into **Applications**.
3. Open SpaceJam. Click **Open Settings…**, drag the app tile into the permission
   list, and enable its switch. macOS may ask for Touch ID or your password.
4. Choose a duration. **100 ms** is the default; try **75 ms** for a quicker slide.

![Drag the app tile into Settings](docs/images/permission-helper.png)

The permission page is under **Privacy & Security**. On macOS 27 it may be
called **Device Control and Data Access** rather than Accessibility. SpaceJam
checks the grant automatically and shows its status at the top of settings.

### Homebrew

```sh
brew tap rkaregaran/spacejam https://github.com/rkaregaran/SpaceJam
brew install --cask spacejam
```

### Terminal

```sh
/bin/bash -c "$(curl --fail --show-error --silent --location --proto '=https' https://raw.githubusercontent.com/rkaregaran/SpaceJam/main/scripts/install.sh)"
```

The installer verifies the release checksum, app signature, and Gatekeeper
approval before copying the app into Applications. It may ask for your Mac
password to write there. It leaves an existing installation intact.

## Use

- Choose **50–1,000 ms** and toggle **Enabled** to pause or resume.
- **Verify switching** moves to a neighboring desktop and returns.
- Closing settings keeps SpaceJam running. **Quit SpaceJam** stops it.
- Turn off **Show in menu bar** for a quieter desktop. Reopen the app from
  Applications to bring settings back.
- Enable **Open at login** to start it automatically after signing in.

Physical trackpad swipes, numbered desktop shortcuts, Mission Control, and
fullscreen desktop transitions retain their native behavior. This release
changes ordinary desktop switching through Control–Left/Right.

SpaceJam must be running to work. **SIP stays enabled.** It does not patch Dock
or change system files. It reads desktop state and sends synthetic gestures
through a private macOS protocol, which can change with an OS update. The app
is limited to macOS 27 and falls back to native shortcuts when it cannot start
or handle an initial shortcut. The duration controls its gesture trajectory;
macOS can add settling time.

## Build & contribute

With Apple's command line tools and SDK 27 on an Apple silicon Mac:

```sh
python3 scripts/build.py
```

See [development notes](docs/DEVELOPMENT.md) and
[signed releases](docs/RELEASING.md). No Bazel, Bazelisk, or runtime package
dependencies are required.

App interface, settings, packaging, and documentation: **MIT**. The adapted
gesture engine is **Apache-2.0**, with credit to Matthew Bowen's
[FasterSwiper](https://github.com/mgbowen/FasterSwiper).
See [license details](THIRD_PARTY_NOTICES.md).
