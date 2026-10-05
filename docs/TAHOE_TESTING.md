# Test SpaceJam on macOS 26 Tahoe

Use an Apple silicon Mac with macOS 26 and at least two ordinary desktops.
Download the [latest stable DMG](https://github.com/rkaregaran/SpaceJam/releases/latest).
Quit an existing SpaceJam, drag the new app to Applications, open it, and
follow the Accessibility prompt. Leave SIP and Gatekeeper enabled.

Record the full macOS version (System Settings → General → About), SpaceJam
version, duration, and whether natural scrolling is on. Start at 100 ms;
repeat the main switching checks at 75 ms if 100 ms works.

1. Click **Verify switching**. It should move to a neighboring ordinary desktop
   and return, leaving the engine enabled with a successful status.
2. Press **Control–Left/Right** in both directions. Check that each shortcut
   moves one desktop in the expected direction. Repeat with natural scrolling
   off and on in System Settings; restore your preferred setting afterward.
3. Open a single-window app on another desktop. Click its running Dock icon.
   It should reach the app's desktop quickly and activate the app. Turn off
   **Speed up Dock app clicks** and compare the native animation, then re-enable.
4. From another desktop, hold Command, press Tab to select that app, then release
   Command. Check speed and correct activation. Repeat with Command–Shift–Tab,
   cancel once with Escape, and compare with **Speed up Command–Tab** off.
   Very quick taps may use native timing if the target is not ready.
5. Pause or quit SpaceJam. Shortcuts, Dock clicks, and Command–Tab should retain
   their normal native behavior. Reopen it and confirm the duration persists.
6. Check that physical trackpad swipes and fullscreen transitions still work
   natively. If available, also try sleep/wake and a second display.

Report pass/fail for each input path and the exact macOS version. For a failure,
include the direction, natural-scrolling setting, requested duration, SpaceJam's
status message, and whether the correct app became active. If a switch stalls,
turn off Enabled or quit SpaceJam before retrying.

These checks validate actual Tahoe behavior. The automated event-format and
routing tests do not post input and cannot replace them.
