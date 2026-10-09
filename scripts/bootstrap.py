#!/usr/bin/env python3
"""Resolve only pinned dependencies, inside the own repository's ignored Vendor folder."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
LOCK = json.loads((ROOT / "Config/dependencies.json").read_text())

def run(arguments, cwd=ROOT, capture=False):
    return subprocess.run(arguments, cwd=cwd, check=True, text=True,
                          capture_output=capture).stdout if capture else subprocess.run(arguments, cwd=cwd, check=True)

def bootstrap():
    sparkle = ROOT / "Vendor/Sparkle"
    sparkle.mkdir(parents=True, exist_ok=True)
    archive = sparkle / "Sparkle.zip"
    pin = LOCK["sparkle"]
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != pin["sha256"]:
        run(["curl", "-fL", "--retry", "2", "--max-time", "120", "-o", str(archive), pin["url"]])
    if hashlib.sha256(archive.read_bytes()).hexdigest() != pin["sha256"]:
        raise RuntimeError("Sparkle distribution digest mismatch")
    if not (sparkle / "Sparkle.xcframework").exists():
        run(["ditto", "-xk", str(archive), str(sparkle)])
    mas = ROOT / "Vendor/mas"
    if not mas.exists():
        run(["git", "clone", "--depth", "1", "--branch", LOCK["mas"]["tag"], LOCK["mas"]["repository"], str(mas)])
    revision = run(["git", "rev-parse", "HEAD"], cwd=mas, capture=True).strip()
    if revision != LOCK["mas"]["revision"]:
        raise RuntimeError("mas source revision mismatch")
    # Swift 6.4 no longer requires two outer unsafe markers; retain all warnings-as-errors.
    compiler = run(["swift", "--version"], capture=True)
    match = re.search(r"Swift version (\d+)\.(\d+)", compiler)
    if match and tuple(map(int, match.groups())) >= (6, 4):
        patch = ROOT / "scripts/mas-sdk27.patch"
        reverse = subprocess.run(["git", "apply", "--reverse", "--check", str(patch)], cwd=mas, capture_output=True)
        if reverse.returncode:
            run(["git", "apply", "--check", str(patch)], cwd=mas)
            run(["git", "apply", str(patch)], cwd=mas)
    run(["swift", "build", "-c", "release", "--disable-automatic-resolution", "--package-path", str(mas), "--product", "mas"])
    print("Verified Sparkle 2.10.0 and built mas v7.0.0 from its pinned source.")

if __name__ == "__main__":
    bootstrap()
