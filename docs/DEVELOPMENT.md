# Developing SpaceJam

## Requirements

Apple silicon, Apple's SDK 27 and command line tools, and Python 3.11 or newer.
The app targets macOS 26 and 27; Tahoe live validation is pending.
Development builds use an ad hoc
signature and are unsuitable for public downloads.

```sh
python3 scripts/build.py --screenshots
python3 scripts/package.py --development
```

The build compiles with warnings treated as errors, verifies the app signature,
and runs event-format, route, Command–Tab routing, and preferences tests.
These tests do not post input.
`--screenshots` renders the actual native views with illustrative permission
states; it does not grant permissions or start the switching engine.

## Structure

- `Sources/AppDelegate.mm`: settings, draggable app tile, menu bar, permission
  polling, login service, and lifecycle handling.
- `Sources/Settings.mm`: persisted duration, enable state, and menu visibility.
- `Sources/SwitchEngine.mm`: shortcut event tap, display/desktop selection,
  Dock/Command–Tab interception, bounded queue, animation, cancellation, and commit verification.
- `Sources/DockTarget.mm`: asynchronous Dock hit testing and focused-window
  desktop lookup, plus native app-switcher selection; no window titles or content
  are read.
- `Sources/SpaceRoute.h`: validation of ordinary-desktop routes for Dock clicks.
- `Sources/ThirdParty/GestureEvents.h`: native IOHID gesture payload and
  CoreGraphics serialization, adapted from FasterSwiper.
- `scripts/`: build, gated release packaging, and end-user installation.

## Switching behavior

Control–Left/Right is intercepted only while the engine is enabled and has
Accessibility permission. It checks the display under the mouse and adjacent
ordinary desktops. Unsupported cases pass through when the initial shortcut
is received; fullscreen Spaces and Mission Control use native switching.

The synthetic gesture follows quadratic ease-out on a 240 Hz run-loop timer.
macOS decides the final presentation timing. After the End event, the engine
checks the current desktop ID before starting another queued move. Up to six
additional presses are queued; extra presses and keyboard autorepeat are
discarded while a handled key is held. A queued move that becomes unsupported
is discarded rather than replaying stale input.

Physical gesture beginnings cancel an in-flight synthetic animation. Tagged
synthetic events are excluded from this check. Pausing, quitting, sleep, and
display changes invalidate the timer and queued callbacks. Permission changes
are polled once per second while settings is visible and every ten seconds
otherwise. Permission revocation stops the listener. An unsuccessful desktop
commit stops the engine until the user toggles Enabled or retries after a
lifecycle change.

SpaceJam reads shortcut keycodes, modifiers, and repeat state. It does not record keystrokes,
write an input log, collect analytics, or make network requests at runtime.

With Dock acceleration enabled, left-button down passes through and starts a
bounded background Accessibility lookup. A ready, unmodified, single-click
release inside the same Dock app tile can be deferred until the target desktop
commits. Replaying the tagged release lets Dock perform normal activation.
Dragging, modified/multiple clicks, slow/failed lookups, minimized focused
windows, conflicting accessible app windows, other displays, and fullscreen
routes remain native. The Dock preference that disables switching to an app's
desktop is respected. Several desktops are traversed as adjacent moves, each
using the selected duration; direct distant jumps are avoided because upstream
reports occasional bounce animations on macOS 27.

A new click, physical gesture, pause, feature disable, or lifecycle cancellation
returns any deferred release to Dock. Target lookup runs off the event-tap
thread, allows one outstanding request, and discards stale results. Some apps
report an empty AXWindows list for off-desktop windows; their focused/main
window is used, so unusual multiwindow apps still need manual validation.

With Command–Tab acceleration enabled, native Tab/Shift–Tab and arrow events
pass through. A background request polls Dock's AXProcessSwitcherList and
AXSelectedChildren while Command is held; it uses a uniquely matching regular
running application's display name. Each navigation change invalidates the
candidate and waits 20 ms before querying the updated native selection. An
unresolved final Command release passes through immediately. A ready target
uses its window's display, validates an ordinary-desktop route, defers the
release, and replays it after commit. Both Command keys are supported; only
release of the last held Command key can trigger the move. Escape, unrelated
keys, and clicks leave activation native. New input during a deferred release
cancels the gesture and inserts the release before that input through the tap.
Feature disable, stop, sleep, and display changes also return the release.

## Validation

Tests cover 35 gesture cases across explicit macOS 26/27 payload conventions,
both directions, natural scrolling, all four phases, and malformed serialized data. They verify both the embedded
payload, velocity, and restored synthetic source tag. Preferences tests use an
isolated temporary domain and check defaults, persistence, and corrupted-duration
bounds. Run these through the build command.
Thirteen Dock route cases cover adjacency, distant targets, same/other display,
fullscreen routes, and malformed desktop metadata. Live Dock checks are
recorded separately in INPUT_PATHS.md. Command–Tab routing tests cover
forward/reverse navigation, arrows, both Command keys, cancellation, extra
modifiers, feature disable, synthetic events, and untouched unresolved releases.

GitHub CI uses the `xcode-27` public-preview runner to build the app and execute
the non-input tests. Test and icon-generator executables have a macOS 13
minimum so they can run on a CI host with SDK 27; the app has a macOS 26
minimum and accepts only macOS 26 and 27 at runtime.
CI does not establish live desktop-switching compatibility or permission
onboarding. Those require a logged-in Mac with multiple desktops.

Before distributing a release, use the manual checks in RELEASING.md on a
clean Mac. Rebuild screenshots after interface changes. Keep development
artifacts and the earlier Dock-patching research out of the public repository.
