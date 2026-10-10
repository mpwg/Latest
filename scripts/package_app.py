#!/usr/bin/env python3
"""Build and sign an own-fork app bundle without registering a helper or installing apps."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent

def run(args, capture=False):
    result = subprocess.run(args, cwd=ROOT, check=True, text=True, capture_output=capture)
    return result.stdout.strip() if capture else None

def package(configuration, identity, team, public_key, version):
    run(["python3", "scripts/bootstrap.py"])
    run(["swift", "build", "-c", configuration])
    binaries = Path(run(["swift", "build", "-c", configuration, "--show-bin-path"], capture=True))
    destination = ROOT / ".build" / configuration / "Latest.app"
    if destination.exists():
        # Only replace this script's generated bundle, never an installed application.
        shutil.rmtree(destination)
    contents = destination / "Contents"
    for folder in ["MacOS", "Resources", "Frameworks", "Library/LaunchDaemons"]:
        (contents / folder).mkdir(parents=True, exist_ok=True)
    shutil.copy2(binaries / "LatestApp", contents / "MacOS/Latest")
    run(["install_name_tool", "-add_rpath", "@executable_path/../Frameworks", str(contents / "MacOS/Latest")])
    for product in ["LatestBroker", "LatestPackageVerifier"]:
        shutil.copy2(binaries / product, contents / "Resources" / product)
    shutil.copy2(ROOT / "Vendor/mas/.build/release/mas", contents / "Resources/mas")
    framework = ROOT / "Vendor/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
    shutil.copytree(framework, contents / "Frameworks/Sparkle.framework", symlinks=True)
    catalogue = json.loads((ROOT / "Sources/LatestApp/Resources/Localizable.xcstrings").read_text())
    for language in ["en", "de"]:
        folder = contents / "Resources" / (language + ".lproj"); folder.mkdir()
        text = "\n".join(json.dumps(key, ensure_ascii=False) + " = " + json.dumps(value["localizations"][language]["stringUnit"]["value"], ensure_ascii=False) + ";" for key,value in catalogue["strings"].items())
        (folder / "Localizable.strings").write_text(text + "\n")
    shutil.copy2(ROOT / "LICENSE.md", contents / "Resources/LICENSE.md")
    shutil.copy2(ROOT / "Vendor/mas/LICENSE", contents / "Resources/mas-LICENSE.txt")
    shutil.copy2(ROOT / "Vendor/Sparkle/LICENSE", contents / "Resources/Sparkle-LICENSE.txt")
    info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
    info.update({"CFBundleIdentifier": "io.github.mpwg.Latest", "CFBundleExecutable": "Latest", "CFBundleShortVersionString": version,
                 "CFBundleVersion": run(["git", "rev-list", "--count", "HEAD"], capture=True), "LatestSigningTeam": team,
                 "SUPublicEDKey": public_key})
    daemon = plistlib.loads((ROOT / "Config/io.github.mpwg.Latest.Broker.plist").read_bytes())
    if team:
        daemon["SpawnConstraint"] = {"team-identifier": team, "signing-identifier": "io.github.mpwg.Latest.Broker"}
    (contents / "Library/LaunchDaemons/io.github.mpwg.Latest.Broker.plist").write_bytes(plistlib.dumps(daemon))
    signing = ["codesign", "--force", "--sign", identity, "--options", "runtime"]
    signing += ["--timestamp"] if identity != "-" and configuration == "release" else ["--timestamp=none"]
    # Sign nested framework components inside out, preserving Sparkle's own identifiers.
    nested = sorted((contents / "Frameworks/Sparkle.framework").rglob("*"), key=lambda p: len(p.parts), reverse=True)
    for path in nested:
        if path.is_symlink(): continue
        if path.suffix in [".app", ".xpc"] or (path.is_file() and os.access(path, os.X_OK) and path.suffix not in [".h", ".swiftinterface"]):
            run(signing + [str(path)])
    run(signing + [str(contents / "Frameworks/Sparkle.framework")])
    for name, identifier in [("mas", "mas"), ("LatestPackageVerifier", "PackageVerifier"), ("LatestBroker", "Broker")]:
        path = contents / "Resources" / name
        run(signing + ["--identifier", "io.github.mpwg.Latest." + identifier, str(path)])
    if identity != "-":
        details = subprocess.run(["codesign", "-dvv", str(contents / "Resources/LatestBroker")], check=True, capture_output=True, text=True)
        actual_team = re.search(r"TeamIdentifier=([A-Z0-9]{10})", details.stderr)
        if not actual_team or actual_team.group(1) != team:
            raise ValueError("Configured team does not match the signing certificate's actual TeamIdentifier")
    info["LatestMasSHA256"] = hashlib.sha256((contents / "Resources/mas").read_bytes()).hexdigest()
    info["LatestVerifierSHA256"] = hashlib.sha256((contents / "Resources/LatestPackageVerifier").read_bytes()).hexdigest()
    (contents / "Info.plist").write_bytes(plistlib.dumps(info))
    run(signing + [str(destination)])
    run(["codesign", "--verify", "--deep", "--strict", str(destination)])
    print(destination)
    return destination

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--configuration", choices=["debug", "release"], default="debug")
    parser.add_argument("--identity", default="-")
    parser.add_argument("--team", default="")
    parser.add_argument("--public-key", default="")
    parser.add_argument("--version", default="1.0.0")
    args = parser.parse_args()
    if args.configuration == "release" and (args.identity == "-" or not args.team or not args.public_key):
        parser.error("Release builds require own signing identity, team and Ed25519 public key")
    package(args.configuration, args.identity, args.team, args.public_key, args.version)
