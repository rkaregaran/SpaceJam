# Dock clicks and trackpad investigation — October 3, 2026

Host: Apple silicon, macOS 27.2 (26B5091g), full SIP enabled. These checks cover
the Dock feature included in v0.2.0. The earlier v0.1.0 release supports
Control–Left/Right only.

## Dock clicks

Dock starts a normal app activation transition on mouse up, not mouse down.
A signed read-only probe confirmed that Dock exposes app URLs through AXURL,
and `_AXUIElementGetWindow` plus `SLSCopySpacesForWindows` resolve the app's
focused window to a desktop without reading window contents or titles.

The implementation lets the down event through, prepares the target on a
background queue, and intercepts only supported release events. It switches
through the existing synthetic-gesture engine, checks the destination ID,
then delivers the release to Dock so the app activates normally. The settings
checkbox persists and can disable this independently of keyboard switching.

Live checks used Muse's focused window on desktop ID 5 from desktop ID 4:

- Native click: desktop ID changed about 290–312 ms after release.
- SpaceJam at 75 ms: about 120–128 ms after release; Muse became frontmost,
  and the engine remained running. A 20 ms button hold also worked.
- Disabling Dock acceleration restored native timing.
- Disabling it about 20 ms into an active synthetic move cancelled before
  desktop commit, closed the animation, and left the engine running. A subsequent
  engine move and return both committed successfully. This establishes gesture
  cleanup, not full second-click or physical-interruption semantics.
- The final signed local build is installed at `/Applications/SpaceJam.app`.
  Its signature verifies, Accessibility is recognized, Dock acceleration is
  enabled, and the existing 75 ms duration, hidden menu bar, and login preference
  remain intact. The installed app's Verify switching control passed a 75 ms
  keyboard-style round trip. The previous notarized app is backed up locally
  under `.local/before-dock-feature/SpaceJam.app`. These checks preceded release
  packaging; distribution verification is recorded separately.

These measurements are elapsed time to the desktop ID change, not frame-level
measurements of the complete visual animation. The native Dock can add settling
time after the synthetic trajectory. Multi-desktop routes use adjacent moves,
each with the selected duration. Fullscreen and other-display routes remain
native. Very fast clicks whose lookup is not ready also remain native.

Some apps expose an empty AXWindows list even though their focused/main window
is valid. WindowServer's broader list also contains app rendering surfaces that
are not real app windows. The resolver uses the focused/main AX window and
rejects conflicting desktops in AXWindows when that list is available. Unusual
multiwindow apps, rapid second clicks, Dock auto-hide/magnification, multiple
displays, and lifecycle interruption need broader hands-on validation.

## Physical trackpad swipes

Feasible, but not implemented in this Dock change. SpaceJam already observes
physical Dock-control gesture events (type 30, HID subtype 23) and cancels its
keyboard animation when one begins. It currently passes the physical gesture
through, including native release/settling.

[FasterSwiper's physical event handler](https://github.com/mgbowen/FasterSwiper/blob/main/src/engine/physical-event-handler.cc)
handles horizontal begin/change/end/cancel events. Begin and change drive a
synthetic gesture to track finger position; end animates the remaining distance
to the neighboring desktop, and cancellation animates back. It scales the
duration to the remaining distance and excludes its own synthetic events.
Its [compatibility notes](https://github.com/mgbowen/FasterSwiper#compatibility)
report macOS 27 support, with issues for vertical gestures and distant jumps.

The appropriate next step is a horizontal gesture continuation path, preserving
finger tracking and reversal/cancellation. It should handle the system's
configured three- or four-finger desktop gesture by recognizing the horizontal
Dock-control event, rather than counting raw touches. Physical event format,
direction, natural scrolling, release versus cancel, and consecutive swipes
must be validated on this Mac with real fingers. Synthetic fixtures cannot
establish hardware recognition or the feel of release/settling.
