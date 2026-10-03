# SpaceJam 0.1.0

Choose how quickly your Mac slides between desktops when you use
Control–Left/Right or mouse buttons mapped to those shortcuts.

- Set a gesture duration from 50 to 1,000 ms; the default is 100 ms.
- See Accessibility status and open the drag-to-Settings permission helper.
- Pause switching, hide the menu bar icon, and choose Open at login.
- Install using a signed, notarized DMG, Homebrew tap, or terminal installer.

Requires Apple silicon, macOS 27, and at least two ordinary desktops.
SpaceJam stays running in the background and works with SIP enabled.

Download `SpaceJam-0.1.0-arm64.dmg`, open it, and drag SpaceJam to Applications.
Open the app and follow its permission instructions. For Homebrew and terminal
installation, see the repository README.

The duration controls the generated gesture; macOS may add settling time.
Physical trackpad swipes, Mission Control, numbered shortcuts, and fullscreen
desktop transitions retain their native behavior. Private macOS interfaces
power this workaround, and an OS update can break compatibility.

The app interface and packaging are MIT licensed. The gesture engine adapts
Matthew Bowen's FasterSwiper under Apache-2.0, with its notices preserved.
