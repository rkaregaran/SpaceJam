#!/usr/bin/env python3
"""Build SpaceJam using Apple tools. Release mode requires Developer ID signing."""
import argparse
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
APP = BUILD / "SpaceJam.app"

def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--identity", default=os.environ.get("SPACEJAM_SIGN_IDENTITY", "-"))
    parser.add_argument("--screenshots", action="store_true")
    args = parser.parse_args()
    if args.release and (args.identity == "-" or not args.identity.startswith("Developer ID Application:")):
        parser.error("Release builds require a Developer ID Application identity. See docs/RELEASING.md.")
    version = (ROOT / "VERSION").read_text().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        parser.error("VERSION must contain a semantic version such as 0.1.0")
    contents = APP / "Contents"
    executable = contents / "MacOS" / "SpaceJam"
    resources = contents / "Resources"
    executable.parent.mkdir(parents=True, exist_ok=True)
    resources.mkdir(exist_ok=True)
    info = dict(CFBundleIdentifier="dev.rzkr.SpaceJam", CFBundleName="SpaceJam",
                CFBundleDisplayName="SpaceJam", CFBundleExecutable="SpaceJam",
                CFBundlePackageType="APPL", CFBundleVersion=version,
                CFBundleShortVersionString=version, CFBundleIconFile="SpaceJam.icns",
                LSMinimumSystemVersion="27.0", LSUIElement=True,
                NSHighResolutionCapable=True, NSPrincipalClass="NSApplication",
                NSHumanReadableCopyright="Copyright © 2026 Reza Karegaran")
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    flags = ["-std=c++20", "-fobjc-arc", "-arch", "arm64", "-mmacosx-version-min=27.0",
             "-O2", "-Wall", "-Wextra", "-Werror", "-Wno-unused-parameter", "-Wno-deprecated-declarations"]
    compiler = ["/usr/bin/xcrun", "clang++", *flags]
    # Build tools/tests can run on older CI hosts with SDK 27. The shipped app
    # keeps its macOS 27 deployment target and runtime compatibility guard.
    utility_compiler = [value.replace("-mmacosx-version-min=27.0", "-mmacosx-version-min=13.0") for value in compiler]
    run(*utility_compiler, "-framework", "AppKit", ROOT / "Sources/IconBuilder.mm", "-o", BUILD / "icon-builder")
    iconset = BUILD / "SpaceJam.iconset"
    run(BUILD / "icon-builder", iconset)
    run("/usr/bin/iconutil", "-c", "icns", iconset, "-o", resources / "SpaceJam.icns")
    sources = [ROOT / "Sources" / name for name in ("main.mm", "AppDelegate.mm", "Settings.mm", "SwitchEngine.mm", "DockTarget.mm")]
    run(*compiler, "-framework", "AppKit", "-framework", "ApplicationServices", "-framework", "QuartzCore",
        "-framework", "ServiceManagement", "-framework", "Carbon", "-F/System/Library/PrivateFrameworks",
        "-framework", "SkyLight", *sources, "-o", executable)
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
        shutil.copy2(ROOT / name, resources / name)
    if (resources / "LICENSES").exists():
        shutil.rmtree(resources / "LICENSES")
    shutil.copytree(ROOT / "LICENSES", resources / "LICENSES")
    signing = ["/usr/bin/codesign", "--force", "--sign", args.identity]
    if args.identity != "-":
        signing += ["--options", "runtime", "--timestamp"]
    run(*signing, APP)
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", APP)
    for name, files in (("event-protocol", ["Tests/EventProtocol.mm"]),
                        ("space-route", ["Tests/SpaceRoute.mm"]),
                        ("command-tab", ["Tests/CommandTab.mm", "Sources/SwitchEngine.mm", "Sources/DockTarget.mm"]),
                        ("settings", ["Tests/Settings.mm", "Sources/Settings.mm"])):
        test = BUILD / f"test-{name}"
        run(*utility_compiler, "-framework", "AppKit", "-framework", "ApplicationServices", "-framework", "QuartzCore",
            "-F/System/Library/PrivateFrameworks", "-framework", "SkyLight", *[ROOT / file for file in files], "-o", test)
        result = subprocess.run([str(test)], capture_output=True, text=True)
        print(result.stdout + result.stderr, end="")
        (BUILD / f"test-{name}.txt").write_text(result.stdout + result.stderr)
        result.check_returncode()
    if args.screenshots:
        run(executable, "--render-screenshots", ROOT / "docs/images")
    print(APP)
    if args.identity == "-":
        print("Development build only; not signed/notarized for public download.")

if __name__ == "__main__":
    main()
