# SpaceJam 0.3.1 — macOS Tahoe test release

SpaceJam now targets Apple silicon Macs running macOS 26 Tahoe or macOS 27.
This prerelease is ready for Tahoe testing; live compatibility on macOS 26
has not yet been established.

- Lower the app deployment target and bundle minimum to macOS 26.0.
- Allow macOS 26 and 27 at runtime; other major versions retain native behavior.
- Preserve the OS-specific natural-scrolling payload convention and test both
  versions, both directions, all gesture phases, and end velocity without
  posting input.
- Keep Control–Left/Right, Dock clicks, and Command–Tab acceleration available.
  Physical trackpad swipes and fullscreen transitions retain native behavior.
- Add an automated prerelease option to the signed release workflow. Test
  downloads are signed, notarized, and stapled through the same pipeline.

Download `SpaceJam-0.3.1-arm64.dmg`, open it, and drag SpaceJam to Applications.
Quit an existing SpaceJam before replacing it. Grant Accessibility, create at
least two ordinary desktops, and start with 100 ms. Follow the
[Tahoe test checklist](https://github.com/rkaregaran/SpaceJam/blob/main/docs/TAHOE_TESTING.md)
and report your exact macOS version plus which paths work or fail.

Homebrew and the latest stable download remain on 0.3.0 for macOS 27 while
Tahoe testing is underway. Use this prerelease DMG on Tahoe.

Private macOS interfaces power this workaround. Signing and notarization verify
distribution, not live desktop-switching compatibility. The app interface and
packaging are MIT licensed; the gesture engine adapts Matthew Bowen's
FasterSwiper under Apache-2.0, with its notices preserved.
