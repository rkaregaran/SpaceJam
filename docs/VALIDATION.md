# Validation — October 2, 2026

Host: Apple silicon, macOS 27.2 build 26B5091g. `csrutil status` confirms full
System Integrity Protection is enabled. The earlier Dock patches are restored.

## Passed

- Native app builds with warnings treated as errors and passes strict signature
  verification with its local development signature.
- The release build is also signed with the existing Developer ID Application
  identity, hardened runtime, and a secure timestamp. Its strict signature
  verification passes. Notarization is still pending.
- 19 event-format cases cover both directions, natural scrolling, gesture
  phases, malformed-data refusal, and source tagging. No input is posted by
  these tests.
- Preferences tests pass for defaults, persistence, and invalid-duration bounds.
- The user granted Accessibility through the macOS Touch ID prompt. The app
  recognized the grant automatically and started its listener.
- The app's Verify switching control completed actual desktop round trips at
  **100 ms** and **75 ms**, checking the destination desktop ID after each move.
  These are requested gesture durations, not measured total presentation times.
- Pause/resume changes the listener state and disables verification while paused.
- Duration **75 ms** and hidden menu bar preference survive quitting and reopening.
- Native views render correctly for the settings and permission-helper images.
- Development DMG checksum verifies. It mounts read-only, contains the correct
  Applications symlink, and has an app whose executable matches the tested
  development build.
  The ZIP extracts with the same executable and a valid signature.
- Public packaging rejects the ad hoc development build before producing a
  public cask. Installer and cask Ruby syntax checks pass.
- The existing rzkr.dev Astro project builds with the article marked as a
  draft. Production pages and RSS exclude it. Its development preview displays
  the article in the existing blog layout with the app image.

## Still required before a public release

- Confirm the physical app-tile drag into Settings on a clean installation.
- Test Open at login after signing in again, sleep/wake, display changes,
  permission revocation, fullscreen fallback, and rapid queued shortcuts.
- Obtain accepted notarization for app and DMG,
  staple tickets, and pass Gatekeeper assessment on a downloaded copy.
- Exercise the terminal installer and Homebrew cask against actual uploaded,
  signed release assets. GitHub-hosted CI has not run yet.

Rebuilding the ad hoc development app invalidated its earlier Accessibility
grant. The Developer ID build now needs its initial refreshed entry. Subsequent
updates should retain the same signing identity and bundle identifier; this
still needs validation on a clean Mac.
