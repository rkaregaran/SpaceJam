# Validation — October 3, 2026

Host: Apple silicon, macOS 27.2 build 26B5091g. `csrutil status` confirms full
System Integrity Protection is enabled. The earlier Dock patches are restored.

## Version 0.2.0 distribution checks

- Developer ID release build passes warning-as-error compilation, 19 gesture
  serialization cases, 13 Dock route cases, preferences tests, and strict
  signature verification. Live Dock and installed-engine checks are in
  [INPUT_PATHS.md](INPUT_PATHS.md).
- Apple accepted notarization for the new app and DMG. Both have validated
  stapled tickets and pass Gatekeeper as Notarized Developer ID.
- The DMG mounts read-only with an Applications symlink. Its app and the
  extracted ZIP have valid signatures/tickets and executables identical to the
  release build. The ZIP app passes Gatekeeper.
- Release-manifest hashes, SHA256SUMS, and the generated v0.2.0 Homebrew cask
  match the final files. Installer/cask syntax and Python compilation pass.
- The refreshed native settings screenshot includes the Dock checkbox and
  v0.2.0 footer. Layout was visually checked.
- The manual GitHub Actions release workflow passes actionlint and every shell
  step passes Bash syntax checks. The known `xcode-27` public-preview runner
  label is excluded from the older linter's label check; existing CI using it
  passes. No release signing secrets are configured in GitHub yet, so signed
  Actions execution remains unverified until those secrets are provided.

## Passed

- Native app builds with warnings treated as errors and passes strict signature
  verification with its local development signature.
- The release build is also signed with the existing Developer ID Application
  identity, hardened runtime, and a secure timestamp. Its strict signature
  verification passes.
- Apple accepted notarization for the release app and DMG. Both have validated
  stapled tickets and pass Gatekeeper as **Notarized Developer ID**.
- The final public DMG mounts read-only with the correct Applications symlink.
  Its app and the extracted public ZIP have valid signatures and stapled tickets,
  and their executables match the release build. The ZIP app passes Gatekeeper.
  Release-manifest checksums and the generated Homebrew cask match the final files.
- The signed release is installed at `/Applications/SpaceJam.app` and passes
  signature, stapled-ticket, and Gatekeeper checks there. The running process is
  the Applications copy. After replacing the stale development permission entry
  with that signed copy, Accessibility is recognized and an actual **75 ms**
  desktop round trip passes. Permission, duration, and hidden menu preference
  survive quitting and reopening the signed app.
- Open at login is registered successfully for the installed signed app;
  the settings checkbox reflects `SMAppServiceStatusEnabled`. Actual startup
  after signing in again still needs a user test.
- The public GitHub release `v0.1.0` is published. Downloaded DMG, ZIP, and
  checksum files match the release manifest; the downloaded ZIP app passes
  signature, stapled-ticket, and Gatekeeper checks.
- The documented Homebrew tap registers successfully and `brew fetch --cask
  rkaregaran/spacejam/spacejam` downloads the published DMG and verifies its hash.
  GitHub's build workflow passes for the release commit.
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

## Remaining manual checks

- Confirm the physical app-tile drag into Settings on a clean installation.
- Test Open at login after signing in again, sleep/wake, display changes,
  permission revocation, fullscreen fallback, and rapid queued shortcuts.
- Exercise complete terminal and Homebrew installation on a clean Mac. Public
  downloads and Homebrew fetching are verified; this Mac already has SpaceJam
  installed, so the terminal installer correctly refuses to overwrite it.

Rebuilding the ad hoc development app invalidated its earlier Accessibility
grant. The Developer ID build now needs its initial refreshed entry. Subsequent
updates should retain the same signing identity and bundle identifier; this
still needs validation on a clean Mac.
