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

## Before the first public release

- Test the signed app on a clean Mac with full SIP enabled: DMG installation,
  drag-to-Settings onboarding, permission revocation, reopening with the menu
  icon hidden, duration persistence, and login startup.
- Review `docs/blog/apple-let-us-set-animation-speed.md` before publication.
- Create the `rkaregaran/SpaceJam` GitHub repository and push the reviewed files.
- Replace the cask template with the generated `Casks/spacejam.rb` and commit it.
- Publish tag `v0.1.0` with the files listed in `dist/release-manifest.json`.

Do not publish the files containing `-dev-` in their names. Public install links
are intentionally not live until the first signed release is uploaded.

## Homebrew

The app repository also works as a tap by specifying its URL explicitly:

```sh
brew tap rkaregaran/spacejam https://github.com/rkaregaran/SpaceJam
brew install --cask spacejam
```

No submission to Homebrew's main cask repository is required for this tap.
Main-repository acceptance is a separate review and must not be implied.

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
