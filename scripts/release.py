#!/usr/bin/env python3
"""Prepare a signed, notarized release and signed feed; publishing is a separate reviewed action."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
UPDATE = json.loads((ROOT/"Config/updates.json").read_text())

def run(arguments, capture=False, input=None):
    result=subprocess.run(arguments,cwd=ROOT,check=True,text=True,capture_output=capture,input=input)
    return result.stdout.strip() if capture else None

def release(version, identity, team, profile):
    if not re.fullmatch(r"\d+\.\d+\.\d+",version): raise ValueError("Use a stable semantic release version")
    private=os.environ.get("SPARKLE_PRIVATE_KEY")
    if not private: raise ValueError("SPARKLE_PRIVATE_KEY is required through the environment")
    run(["swift","build","-c","release","--product","LatestRelease"])
    public=run([".build/release/LatestRelease","public-key","-"],capture=True,input=private)
    if public != UPDATE["publicKey"]: raise ValueError("Private update key does not match the committed public key")
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
    namespace="http://www.andymatuschak.org/xml-namespaces/sparkle"
    ET.register_namespace("sparkle",namespace)
    rss=ET.Element("rss",version="2.0");channel=ET.SubElement(rss,"channel")
    ET.SubElement(channel,"title").text="Latest — mpwg fork"
    ET.SubElement(channel,"link").text="https://github.com/mpwg/Latest"
    item=ET.SubElement(channel,"item");ET.SubElement(item,"title").text="Latest "+version
    ET.SubElement(item,"{%s}minimumSystemVersion"%namespace).text="27.0"
    build=run(["git","rev-list","--count","HEAD"],capture=True)
    ET.SubElement(item,"enclosure",{"url":f"https://github.com/mpwg/Latest/releases/download/v{version}/Latest.zip","length":str(archive.stat().st_size),"type":"application/octet-stream","{%s}version"%namespace:build,"{%s}shortVersionString"%namespace:version,"{%s}edSignature"%namespace:signature})
    unsigned=destination/"appcast-unsigned.xml"
    unsigned.write_bytes(ET.tostring(rss,encoding="utf-8",xml_declaration=True)+b"\n")
    run([".build/release/LatestRelease","sign-feed","-",str(unsigned),str(destination/"appcast.xml")],input=private)
    (destination/"source-revision.txt").write_text(run(["git","rev-parse","HEAD"],capture=True)+"\n")
    run(["git","archive","--format=tar.gz","--output",str(destination/"source.tar.gz"),"HEAD"])
    print("Prepared release artifacts:",destination)

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--version",required=True);p.add_argument("--identity",required=True)
    p.add_argument("--team",required=True);p.add_argument("--notary-profile",required=True)
    a=p.parse_args();release(a.version,a.identity,a.team,a.notary_profile)
