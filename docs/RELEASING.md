# Release SpaceJam

Public downloads need a **Developer ID Application** signature and Apple
notarization. Development builds are for local testing and do not provide the
download-and-open experience.

## One-time local setup

1. Import your Developer ID Application certificate **and its private key**
   into the login keychain. Use Keychain Access or create the certificate from
   your Apple Developer account. Keep keys and passwords on your Mac; do not
   paste them into chat or commit them.
2. Confirm the identity is available:

   ```sh
   security find-identity -v -p codesigning
   ```

3. Store notarization credentials in Keychain using Apple's interactive flow:

   ```sh
   xcrun notarytool store-credentials SpaceJam-notary
   ```

   You can use an Apple ID with an app-specific password or an App Store Connect
   API key. Follow the local prompts. Credentials stay out of this repository.

## Build and notarize

```sh
export SPACEJAM_SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)'
python3 scripts/build.py --release
python3 scripts/package.py --notary-profile SpaceJam-notary
```

The package command checks the signature, submits a temporary ZIP to Apple,
staples the accepted ticket to the app, checks Gatekeeper, then creates the
installer DMG and the ZIP used by the terminal installer. The DMG is also
signed, notarized, and stapled. It writes SHA-256 checksums and a Homebrew cask
using the actual final DMG hash. It refuses to publish an ad hoc build.

## Publish a local release

- Test the signed app on a clean Mac with full SIP enabled: DMG installation,
  drag-to-Settings onboarding, permission revocation, reopening with the menu
  icon hidden, duration persistence, and login startup.
- Review `docs/blog/apple-let-us-set-animation-speed.md` before publication.
- Bump `VERSION`, update `docs/RELEASE_NOTES.md` and README, and refresh native
  screenshots with `scripts/build.py --release --screenshots`.
- Confirm the `rkaregaran/SpaceJam` GitHub repository is public and push the reviewed files.
- Replace the cask template with the generated `Casks/spacejam.rb` and commit it.
- Tag the reviewed commit as `v<VERSION>` and publish the DMG, ZIP, SHA256SUMS,
  and `dist/release-manifest.json`. Use `docs/RELEASE_NOTES.md` for the release body.

Do not publish files containing `-dev-` in their names. The latest-download
links and terminal installer follow the most recently published release.

## Homebrew

The app repository also works as a tap by specifying its URL explicitly:

```sh
brew tap rkaregaran/spacejam https://github.com/rkaregaran/SpaceJam
brew install --cask spacejam
```

No submission to Homebrew's main cask repository is required for this tap.
Main-repository acceptance is a separate review and must not be implied.
After a release, verify `brew fetch --cask rkaregaran/spacejam/spacejam` against
the regenerated cask. Existing users upgrade with `brew update`, then
`brew upgrade --cask rkaregaran/spacejam/spacejam`.

## GitHub Actions releases

The **Signed release** workflow is manually triggered from Actions on `main`.
Normal pushes and pull requests run the existing unsigned build/tests and do
not use distribution credentials. Before triggering a release, bump VERSION
and update the notes/screenshots on main. An existing version tag is refused.

Configure these repository Actions secrets before the first run:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64 of a password-protected `.p12` containing the Developer ID Application certificate and its private key |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password chosen when exporting that `.p12` |
| `DEVELOPER_ID_IDENTITY` | Full `Developer ID Application: NAME (TEAMID)` identity |
| `APPLE_ID` | Apple account used for notarization |
| `APPLE_TEAM_ID` | Developer team identifier |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for notarization |

Use GitHub's secret-entry UI or `gh secret set` via stdin; never commit signing
material or print secret values. This setup follows
[GitHub's signing guidance](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications).
The local Keychain profile is not copied automatically to GitHub.

Select **verify_only** to exercise the entire signing, notarization, and packaging
pipeline without changing the cask, tags, or public release. This mode allows an
already released VERSION and saves the verified artifacts on the Actions run.

The workflow imports credentials into a temporary runner keychain, builds and
tests, notarizes/staples the app and DMG, verifies Gatekeeper, and saves the
artifacts for 30 days. It then commits the exact DMG checksum to the Homebrew
cask, tags that commit, uploads a draft release, and publishes it as latest.
The runner's temporary keychain and certificate are removed even on failure.
The repository must allow the workflow token to push the generated cask commit.

If main advances during packaging, publishing stops and the verified artifacts
remain downloadable from the run. If publishing fails after creating the tag,
recover using those saved artifacts and the generated cask; do not overwrite an
existing release with a fresh rebuild, whose signing timestamps change hashes.

## Local development package

```sh
python3 scripts/build.py
python3 scripts/package.py --development
```

This creates a clearly named local development DMG. It does not notarize the
app, generate a public cask, or bypass Gatekeeper. Rebuilding an ad hoc app can
invalidate its Accessibility grant. Remove only SpaceJam's stale entry and drag
the rebuilt app into the list again. Developer ID releases retain a consistent
signing identity, but moving the app or changing signing requirements can still
require a fresh grant.
