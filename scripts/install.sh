#!/bin/bash
# SPDX-License-Identifier: MIT
# Install the latest signed release. Never disables Gatekeeper or strips quarantine.
set -euo pipefail

spacejam_repository="rkaregaran/SpaceJam"
spacejam_asset="SpaceJam-arm64.zip"
spacejam_destination="/Applications/SpaceJam.app"
spacejam_scratch="$(mktemp -d "${TMPDIR:-/tmp}/spacejam-install.XXXXXX")"
trap 'rm -rf "$spacejam_scratch"' EXIT

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "SpaceJam requires a Mac with Apple silicon." >&2; exit 1
fi
spacejam_major="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$spacejam_major" != "27" ]]; then
  echo "This release supports macOS 27." >&2; exit 1
fi
if [[ -e "$spacejam_destination" ]]; then
  echo "SpaceJam is already installed. Quit it and replace it using the latest DMG, or use Homebrew to upgrade." >&2
  exit 1
fi
spacejam_base="https://github.com/${spacejam_repository}/releases/latest/download"
echo "Downloading SpaceJam…"
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 "$spacejam_base/$spacejam_asset" -o "$spacejam_scratch/$spacejam_asset"
curl --fail --show-error --silent --location --proto '=https' --tlsv1.2 "$spacejam_base/SHA256SUMS" -o "$spacejam_scratch/SHA256SUMS"
spacejam_expected="$(awk -v filename="$spacejam_asset" '$2 == filename { print $1 }' "$spacejam_scratch/SHA256SUMS")"
if [[ ! "$spacejam_expected" =~ ^[a-f0-9]{64}$ ]]; then
  echo "The release checksum is missing or invalid." >&2; exit 1
fi
spacejam_actual="$(shasum -a 256 "$spacejam_scratch/$spacejam_asset" | awk '{print $1}')"
if [[ "$spacejam_actual" != "$spacejam_expected" ]]; then
  echo "Checksum verification failed. Nothing was installed." >&2; exit 1
fi
/usr/bin/ditto -x -k "$spacejam_scratch/$spacejam_asset" "$spacejam_scratch/unpacked"
spacejam_app="$spacejam_scratch/unpacked/SpaceJam.app"
spacejam_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$spacejam_app/Contents/Info.plist")"
if [[ "$spacejam_identifier" != "dev.rzkr.SpaceJam" ]]; then
  echo "Unexpected app identity. Nothing was installed." >&2; exit 1
fi
/usr/bin/codesign --verify --deep --strict "$spacejam_app"
/usr/sbin/spctl --assess --type execute --verbose=2 "$spacejam_app"
if [[ -w /Applications ]]; then
  /usr/bin/ditto "$spacejam_app" "$spacejam_destination"
else
  sudo /usr/bin/ditto "$spacejam_app" "$spacejam_destination"
fi
echo "Installed. Open SpaceJam from Applications to enable Accessibility."
open "$spacejam_destination"
