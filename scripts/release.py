#!/usr/bin/env python3
"""Prepare a signed, notarized release and signed feed; publishing is a separate reviewed action."""
from pathlib import Path
import argparse
import json
import os
import subprocess
from appcast import MAX_FEED_BYTES, merge_feed, version_tuple

ROOT = Path(__file__).resolve().parent.parent
UPDATE = json.loads((ROOT/"Config/updates.json").read_text())

def run(arguments, capture=False, input=None):
    result=subprocess.run(arguments,cwd=ROOT,check=True,text=True,capture_output=capture,input=input)
    return result.stdout.strip() if capture else None

def release(version, identity, team, profile, existing_feed=None, first_release=False):
    version_tuple(version)
    if (existing_feed is not None) == first_release:
        raise ValueError('Specify exactly one of --existing-feed or --first-release; history is never silently discarded.')
    private=os.environ.get("SPARKLE_PRIVATE_KEY")
    if not private: raise ValueError("SPARKLE_PRIVATE_KEY is required through the environment")
    run(["swift","build","-c","release","--product","LatestRelease"])
    public=run([".build/release/LatestRelease","public-key","-"],capture=True,input=private)
    if public != UPDATE["publicKey"]: raise ValueError("Private update key does not match the committed public key")
    existing = None
    if existing_feed is not None:
        path = Path(existing_feed)
        if path.stat().st_size > MAX_FEED_BYTES: raise ValueError('Existing appcast exceeds the feed size limit.')
        existing = path.read_bytes()
        # Authenticate exactly the bytes that will be merged, avoiding a second file read.
        run([".build/release/LatestRelease", "verify-feed", public, "-"], input=existing.decode('utf-8'))
    build=run(["git","rev-list","--count","HEAD"],capture=True)
    # Fail on malformed history, duplicates and regressions before packaging/notarizing.
    merge_feed(existing, version=version, build=build, length=1, signature='A'*86+'==')
    run(["python3","scripts/package_app.py","--configuration","release","--identity",identity,"--team",team,"--public-key",public,"--version",version])
    destination=ROOT/".release"/version;destination.mkdir(parents=True,exist_ok=True)
    archive=destination/"Latest.zip"
    app=ROOT/".build/release/Latest.app"
    run(["ditto","-c","-k","--keepParent",str(app),str(archive)])
    run(["xcrun","notarytool","submit",str(archive),"--keychain-profile",profile,"--wait"])
    run(["xcrun","stapler","staple",str(app)])
    run(["xcrun","stapler","validate",str(app)])
    # Sign the final stapled archive, not the pre-notarization bytes.
    run(["ditto","-c","-k","--keepParent",str(app),str(archive)])
    signature=run([".build/release/LatestRelease","sign","-",str(archive)],capture=True,input=private)
    unsigned=destination/"appcast-unsigned.xml"
    unsigned.write_bytes(merge_feed(existing, version=version, build=build, length=archive.stat().st_size, signature=signature))
    run([".build/release/LatestRelease","sign-feed","-",str(unsigned),str(destination/"appcast.xml")],input=private)
    run([".build/release/LatestRelease","verify-feed",public,str(destination/"appcast.xml")])
    (destination/"source-revision.txt").write_text(run(["git","rev-parse","HEAD"],capture=True)+"\n")
    run(["git","archive","--format=tar.gz","--output",str(destination/"source.tar.gz"),"HEAD"])
    print("Prepared release artifacts:",destination)

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--version",required=True);p.add_argument("--identity",required=True)
    p.add_argument("--team",required=True);p.add_argument("--notary-profile",required=True)
    history=p.add_mutually_exclusive_group(required=True)
    history.add_argument('--existing-feed',type=Path)
    history.add_argument('--first-release',action='store_true')
    a=p.parse_args();release(a.version,a.identity,a.team,a.notary_profile,a.existing_feed,a.first_release)
