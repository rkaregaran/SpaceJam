# Developing SpaceJam

## Requirements

Apple silicon, Apple's SDK 27 and command line tools, and Python 3.11 or newer.
Running the shipped app requires macOS 27. Development builds use an ad hoc
signature and are unsuitable for public downloads.

```sh
python3 scripts/build.py --screenshots
python3 scripts/package.py --development
```

The build compiles with warnings treated as errors, verifies the app signature,
and runs event-format and preferences tests. Neither test posts input.
`--screenshots` renders the actual native views with illustrative permission
states; it does not grant permissions or start the switching engine.

## Structure

- `Sources/AppDelegate.mm`: settings, draggable app tile, menu bar, permission
  polling, login service, and lifecycle handling.
- `Sources/Settings.mm`: persisted duration, enable state, and menu visibility.
- `Sources/SwitchEngine.mm`: shortcut event tap, display/desktop selection,
  bounded queue, animation, cancellation, and commit verification.
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

SpaceJam reads only the arrow key fields it needs. It does not record keystrokes,
write an input log, collect analytics, or make network requests at runtime.

## Validation

Tests cover 19 gesture cases across both directions, natural scrolling,
all four phases, and malformed serialized data. They verify both the embedded
payload and restored synthetic source tag. Preferences tests use an isolated
temporary domain and check defaults, persistence, and corrupted-duration
bounds. Run these through the build command.

GitHub CI uses the `xcode-27` public-preview runner to build the app and execute
the non-input tests. Test and icon-generator executables have a macOS 13
minimum so they can run on a CI host with SDK 27; the app remains macOS 27-only.
CI does not establish live desktop-switching compatibility or permission
onboarding. Those require a logged-in Mac with multiple desktops.

Before distributing a release, use the manual checks in RELEASING.md on a
clean Mac. Rebuild screenshots after interface changes. Keep development
artifacts and the earlier Dock-patching research out of the public repository.
