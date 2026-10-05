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

## Command–Tab / 0.3.0 preparation (October 3, 2026)

- Signed arm64 build passed with warnings as errors. All event serialization,
  desktop route, settings, and Command–Tab routing tests passed without posting
  input. New preference defaults on and persists independently.
- Native settings/onboarding screenshots were regenerated and inspected.
- Live signed engine checks covered forward/reverse Command–Tab, Escape, feature
  disable during a move, and a subsequent desktop move. At 75 ms, prepared
  Command–Tab targets committed in about 111 ms versus 286 ms natively. Muse
  activated correctly. Details and limitations are recorded in INPUT_PATHS.md.
- Command release is preserved unchanged if the native target is unresolved.
  Deterministic routing checks include right-click and scroll cancellation.
- Public v0.2.0 remains the published release while 0.3.0 is prepared. The
  Homebrew cask on main must retain the published DMG URL/checksum until release
  publication; a locally generated 0.3.0 cask is saved with the local artifacts.
- The release workflow has a linted verification-only option. Cloud signing
  verification is pending explicit approval to upload the Developer ID private
  key and secure entry of Apple notarization credentials; no credentials were
  transferred during this preparation.

The app and DMG from the first 0.3.0 packaging pass were accepted by Apple,
stapled, and accepted by Gatekeeper. A final input-safeguard build then passed
all tests, but its notarization attempt could not access the profile after the
Mac locked. Preliminary notarized artifacts are preserved locally; they are
not published or offered as the final build. Finishing final packaging and
installed-app verification requires manually unlocking the Mac.

After unlocking, the final 0.3.0 app and DMG were both notarized, stapled,
and accepted by Gatekeeper. The Developer ID certificate/private key were
uploaded with explicit user authorization into encrypted Actions secrets;
the encrypted temporary export was deleted. Signing identity/team metadata
are configured. Cloud workflow verification still requires direct secure entry
of the Apple ID and app-specific notarization password.

The final ZIP, DMG, and build contain the same 0.3.0 executable. The DMG’s
Applications link and both recorded checksums were verified. The notarized
app is installed at /Applications/SpaceJam.app; the previous app is backed up
under .local/before-command-tab/SpaceJam.app. Installed settings retain 75 ms,
Dock acceleration on, menu icon hidden, and login startup on. Command–Tab
acceleration defaults on. Accessibility is recognized and the installed Verify
switching control passed its 75 ms round trip. GitHub build/tests passed on
3eabc0c68b8ce43b15d6a8f0db168a69521d3c77 (run 37148427770).


## macOS 26/27 targeting — 0.3.1 test release (October 5, 2026)

- On the macOS 27.2 host, the arm64 app compiles with warnings treated as errors,
  has bundle minimum 26.0, and its Mach-O LC_BUILD_VERSION records minos 26.0.
- All 35 non-input gesture serialization cases pass. Explicit macOS 26 and 27
  cases check both directions, natural scrolling, every phase, source tagging,
  and end velocity; malformed serialization is refused. This validates the
  payload conventions on this host, not macOS 26's native handling.
- All 13 desktop-route cases, Command–Tab routing, and settings tests pass.
  Installer/cask syntax, Python compilation, and Actions lint pass.
- The signed workflow can publish a prerelease without changing the stable
  Homebrew cask or latest release. The template for the next stable release
  accepts Tahoe through Golden Gate; the published 0.3.0 cask remains unchanged.
- Actual Tahoe switching, app activation, and onboarding are pending the user's
  second Mac. Follow TAHOE_TESTING.md before publishing Tahoe support as stable.

The [cloud build](https://github.com/rkaregaran/SpaceJam/actions/runs/37382587652)
and [signed prerelease pipeline](https://github.com/rkaregaran/SpaceJam/actions/runs/37382610255)
both passed for source commit 01447b8de7b72c9746efd0a218170b433c5e5989.
[Version 0.3.1](https://github.com/rkaregaran/SpaceJam/releases/tag/v0.3.1)
is published as a prerelease; v0.3.0 remains latest and the stable cask is unchanged.
Downloaded public DMG/ZIP checksums match SHA256SUMS and the manifest. Both
apps have a 26.0 bundle and Mach-O minimum, matching arm64 executables, valid
Developer ID signatures/stapled tickets, and Gatekeeper acceptance. The DMG
also passes image integrity, stapled-ticket, and Gatekeeper checks and contains
the expected Applications symlink. This establishes distribution checks; live
Tahoe validation remains pending.


## Stable macOS 26/27 support — 0.3.2 preparation (October 5, 2026)

The user tested the published 0.3.1 release on their macOS 26 computer and
reported that all requested checks worked: Verify switching, Control–Left/Right,
Dock app clicks, and Command–Tab. They authorized stable publication and
Homebrew distribution. The exact Tahoe point release/build, durations, and
individual optional checks were not separately reported; this is user-reported
validation, not measured results from this workstation.

Version 0.3.2 retains the tested switching implementation. Release metadata,
installation guidance, and compatibility notes now describe stable Tahoe
support. The production pipeline will rebuild, test, sign, notarize, publish
as latest, and generate the Homebrew cask from the final DMG checksum.

Local 0.3.2 warning-as-error build and signature verification passed, along
with all 35 gesture-format cases, 13 desktop-route cases, Command–Tab routing,
and settings tests. Installer/cask syntax, Python compilation, and Actions
lint also passed. Native screenshots were refreshed for 0.3.2; settings and
permission-helper layout were inspected. No input was posted by these checks.
