# SpaceJam 0.3.0

Command–Tab can now use your chosen desktop-switching duration, alongside
Control–Left/Right, mapped mouse buttons, and Dock app clicks.

- Keep the native macOS app switcher, including Command–Shift–Tab and arrow
  navigation. Escape still cancels.
- Toggle **Speed up Command–Tab** independently in settings; it is on by default.
- Supported switches reach the selected app's ordinary desktop before macOS
  activates it. Fullscreen, ambiguous windows/app names, and unresolved quick
  taps retain native behavior. Distant routes use adjacent moves, each at the
  chosen duration.
- New input or disabling the feature returns any held Command release, so
  subsequent keys and modifiers keep their normal behavior.
- Future releases can be built, signed, notarized, and packaged through the
  manual Signed release workflow, including a verification-only mode. Publishing
  regenerates the Homebrew cask from the final notarized DMG checksum.

At a 75 ms setting on macOS 27.2, live supported Command–Tab switches changed
the desktop ID in roughly 111 ms, compared with 286 ms natively. These are
elapsed desktop-state timings, not measurements of every rendered frame.
The selected duration controls the gesture; macOS can add settling time.

Requires Apple silicon, macOS 27, and at least two ordinary desktops. Physical
trackpad swipes, Mission Control, numbered shortcuts, and fullscreen transitions
retain their native behavior. Private macOS interfaces power this workaround,
and an OS update can break compatibility.

For an existing installation, quit SpaceJam before replacing the app. Download
`SpaceJam-0.3.0-arm64.dmg`, open it, and drag SpaceJam to Applications. Homebrew
users can run `brew update` then `brew upgrade --cask rkaregaran/spacejam/spacejam`
after publication. For other installation methods, see the repository README.

The app interface and packaging are MIT licensed. The gesture engine adapts
Matthew Bowen's FasterSwiper under Apache-2.0, with its notices preserved.
