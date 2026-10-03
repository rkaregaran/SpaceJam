#!/usr/bin/env python3
"""Package a verified app. Public artifacts require Developer ID + notarization."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/SpaceJam.app"
DIST = ROOT / "dist"
REPOSITORY = "rkaregaran/SpaceJam"

def run(*args, **kwargs):
    return subprocess.run([str(value) for value in args], check=True, **kwargs)

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def zip_app(destination):
    if destination.exists():
        destination.unlink()
    run("/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", APP, destination)

def notarize(path, profile):
    result = run("/usr/bin/xcrun", "notarytool", "submit", path, "--keychain-profile", profile,
                 "--wait", "--output-format", "json", capture_output=True, text=True)
    report = json.loads(result.stdout)
    (DIST / f"{path.name}.notarization.json").write_text(json.dumps(report, indent=2) + "\n")
    if report.get("status") != "Accepted":
        raise SystemExit(f"Notarization was not accepted: {report.get('status')}. No public cask generated.")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--development", action="store_true")
    parser.add_argument("--notary-profile", default="SpaceJam-notary")
    args = parser.parse_args()
    if not APP.is_dir():
        parser.error("Build the app first with scripts/build.py")
    info = plistlib.loads((APP / "Contents/Info.plist").read_bytes())
    version = info["CFBundleShortVersionString"]
    if info["CFBundleIdentifier"] != "dev.rzkr.SpaceJam" or not re.fullmatch(r"\d+\.\d+\.\d+", version):
        parser.error("Unexpected bundle identity or version")
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", APP)
    signature = run("/usr/bin/codesign", "-dv", "--verbose=4", APP, capture_output=True, text=True).stderr
    match = re.search(r"^TeamIdentifier=([A-Z0-9]{10})$", signature, re.MULTILINE)
    if not args.development and (not match or "Authority=Developer ID Application:" not in signature or "runtime" not in signature):
        parser.error("Public packages require Developer ID signing and hardened runtime. Build with --release.")
    DIST.mkdir(exist_ok=True)
    suffix = "-dev" if args.development else ""
    zip_path = DIST / f"SpaceJam{suffix}-arm64.zip"
    dmg_path = DIST / f"SpaceJam-{version}{suffix}-arm64.dmg"
    if not args.development:
        submission = DIST / "SpaceJam-notarization.zip"
        zip_app(submission)
        notarize(submission, args.notary_profile)
        run("/usr/bin/xcrun", "stapler", "staple", APP)
        run("/usr/bin/xcrun", "stapler", "validate", APP)
        run("/usr/sbin/spctl", "--assess", "--type", "execute", "--verbose=2", APP)
        submission.unlink()
    zip_app(zip_path)
    with tempfile.TemporaryDirectory(prefix="spacejam-dmg-") as folder:
        stage = Path(folder)
        run("/usr/bin/ditto", APP, stage / "SpaceJam.app")
        (stage / "Applications").symlink_to("/Applications", target_is_directory=True)
        (stage / "Install SpaceJam.txt").write_text(
            "Drag SpaceJam.app to Applications.\n\n"
            "Open SpaceJam from Applications. Click Open Settings, then drag the app tile into the permission list and enable its switch.\n\n"
            "SpaceJam changes desktop switching from Control–Left/Right and mouse shortcuts. It runs in the background; reopen it to change settings.\n"
            + ("\nDEVELOPMENT BUILD: not notarized for public download.\n" if args.development else ""))
        run("/usr/bin/hdiutil", "create", "-volname", "SpaceJam", "-srcfolder", stage,
            "-format", "UDZO", "-ov", dmg_path)
    run("/usr/bin/hdiutil", "verify", dmg_path)
    if not args.development:
        identity = re.search(r"^Authority=(Developer ID Application:.*)$", signature, re.MULTILINE).group(1)
        run("/usr/bin/codesign", "--sign", identity, "--timestamp", dmg_path)
        notarize(dmg_path, args.notary_profile)
        run("/usr/bin/xcrun", "stapler", "staple", dmg_path)
        run("/usr/bin/xcrun", "stapler", "validate", dmg_path)
        run("/usr/sbin/spctl", "--assess", "--type", "open", "--context", "context:primary-signature", "--verbose=2", dmg_path)
        template = (ROOT / "Casks/spacejam.rb.in").read_text()
        cask = template.replace("@VERSION@", version).replace("@SHA256@", digest(dmg_path))
        (ROOT / "Casks/spacejam.rb").write_text(cask)
    sums = DIST / ("SHA256SUMS-dev" if args.development else "SHA256SUMS")
    sums.write_text("".join(f"{digest(path)}  {path.name}\n" for path in (dmg_path, zip_path)))
    manifest = dict(version=version, repository=REPOSITORY, development=args.development,
                    team_id=match.group(1) if match else None,
                    assets=[dict(name=path.name, sha256=digest(path)) for path in (dmg_path, zip_path, sums)])
    manifest_path = DIST / ("development-manifest.json" if args.development else "release-manifest.json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(dmg_path)
    print("Local development artifact; public release remains gated by signing/notarization." if args.development else "Signed/notarized release artifacts and Homebrew cask are ready.")

if __name__ == "__main__":
    main()
