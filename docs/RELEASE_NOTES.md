# SpaceJam 0.2.0

Choose how quickly your Mac slides between desktops when you use
Control–Left/Right, mouse buttons mapped to those shortcuts, or supported
clicks on running apps in the Dock.

- Set a gesture duration from 50 to 1,000 ms; the default is 100 ms.
- See Accessibility status and open the drag-to-Settings permission helper.
- Pause switching, hide the menu bar icon, and choose Open at login.
- Install using a signed, notarized DMG, Homebrew tap, or terminal installer.
- Speed up Dock app clicks with the same duration setting. The feature can
  be disabled independently. Dragging, modified clicks, minimized focused
  windows, fullscreen routes, and unsupported destinations remain native.

Dock clicks now resolve the app's focused/main window, switch to its desktop,
then let Dock activate the app. At a 75 ms setting on the test Mac, the desktop
ID changed in roughly 120–128 ms after release, compared with 290–312 ms natively.
These are desktop-state timings, not measurements of every rendered frame.
Distant destinations use adjacent moves, each with the selected duration.

Requires Apple silicon, macOS 27, and at least two ordinary desktops.
SpaceJam stays running in the background and works with SIP enabled.

Download `SpaceJam-0.2.0-arm64.dmg`, open it, and drag SpaceJam to Applications.
Open the app and follow its permission instructions. For Homebrew and terminal
installation, see the repository README.

For an existing installation, quit SpaceJam before replacing the app.
Homebrew users can run `brew update` followed by
`brew upgrade --cask rkaregaran/spacejam/spacejam`.

The duration controls the generated gesture; macOS may add settling time.
Physical trackpad swipes, Mission Control, numbered shortcuts, and fullscreen
desktop transitions retain their native behavior. Private macOS interfaces
power this workaround, and an OS update can break compatibility.

The app interface and packaging are MIT licensed. The gesture engine adapts
Matthew Bowen's FasterSwiper under Apache-2.0, with its notices preserved.
