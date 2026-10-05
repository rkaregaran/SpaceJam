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

## Command–Tab — v0.3.0

The native switcher appears as Dock's AXProcessSwitcherList. Its single
AXSelectedChildren entry is an AXButton whose title is the app's display name;
it has no app URL or process ID. SpaceJam uses an exact, unique running-app
match, then applies the same focused-window and ambiguity checks as Dock clicks.
It reads app names, not window titles or content, and does not infer native MRU
ordering. Lookup runs while Command is held and each navigation change discards
the previous candidate. Only a ready, validated final Command release is held.
The target window's display selects the gesture route. Native activation follows
the desktop commit, including adjacent steps for distant destinations.

On the same macOS 27.2 host, a live signed integration harness selected Muse's
window 1306 on desktop 5 from desktop 4. With a 75 ms setting, the original
lookup-on-release prototype took about 139 ms to change desktop ID. Preparing
the selection while Command is held reduced that to about 111 ms. The native
comparison took about 286 ms. Muse became frontmost and the engine stayed
running. These are desktop-ID timings, not frame-level animation measurements.

Very fast taps may complete before Dock exposes any switcher list. An initial
prototype that deferred an unresolved release could lose activation; it was
replaced with an untouched native release for that case. Routing tests verify
that fallback. The synthetic quick-tap harness also failed to reliably activate
its intended app with acceleration disabled, so it cannot establish physical
quick-tap performance. Physical keyboard timing, multiple displays, unusual
app names, and multiwindow cases still need broader hands-on validation.

The final implementation also passed reverse Command–Shift–Tab (about 111 ms,
Muse frontmost), Escape cancellation (no desktop move, switcher closed), and
feature disable about 25 ms into an active move (animation closed, native
activation reached Muse in about 330 ms, engine remained running). A subsequent
ordinary desktop move returned successfully. Non-input routing tests additionally
cover arrows, both Command keys, extra modifiers, mouse cancellation, stopped
and disabled engines, own tagged events, and unchanged unresolved releases.


## Tahoe — stable support in v0.3.2

The user tested v0.3.1 on a macOS 26 computer and reported successful Verify
switching, Control–Left/Right, Dock clicks, and Command–Tab, then authorized
stable publication. Version 0.3.2 uses the same switching implementation.
The exact OS point release/build and measured timings were not supplied.
The macOS 27 timings above must not be interpreted as Tahoe measurements.
