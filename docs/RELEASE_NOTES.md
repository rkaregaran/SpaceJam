# SpaceJam 0.3.2

SpaceJam now supports Apple silicon Macs running **macOS 26 Tahoe and macOS 27**.
Tahoe support is available through the stable DMG, Homebrew, and terminal installer.

- Enable the existing Control–Left/Right, supported Dock-click, and Command–Tab
  acceleration on macOS 26 as well as 27.
- Keep the natural-scrolling gesture convention appropriate to each OS version.
- Require macOS 26.0 or newer to launch, with acceleration enabled only on
  macOS 26 and 27. Intel Macs remain unsupported.

The user reports that all requested Tahoe checks worked with the 0.3.1 test
release: Verify switching, Control–Left/Right, Dock app clicks, and Command–Tab.
This stable release uses the same switching implementation. Automated checks
cover both OS payload conventions, desktop routes, Command–Tab routing, and
preferences; downloads are Developer ID signed and notarized by Apple.

Download `SpaceJam-0.3.2-arm64.dmg`, quit an existing SpaceJam, and drag the new
app to Applications. Homebrew users can run:

```sh
brew update
brew upgrade --cask rkaregaran/spacejam/spacejam
```

Requires at least two ordinary desktops and Accessibility permission. Physical
trackpad swipes and fullscreen transitions retain native behavior. Private
macOS interfaces power this workaround, and future OS updates can affect it.

The app interface and packaging are MIT licensed. The gesture engine adapts
Matthew Bowen's FasterSwiper under Apache-2.0, with its notices preserved.
