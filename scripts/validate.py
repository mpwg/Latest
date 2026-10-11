#!/usr/bin/env python3
"""Validate source boundaries, localization and project resource syntax."""
from pathlib import Path
import json
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
catalogue = json.loads((ROOT / "Sources/LatestApp/Resources/Localizable.xcstrings").read_text())
assert catalogue["sourceLanguage"] == "en"
for key,value in catalogue["strings"].items():
    for language in ["en", "de"]:
        unit = value["localizations"][language]["stringUnit"]
        assert unit["state"] == "translated" and unit["value"], (key, language)
        assert re.findall(r"%(?:\d+\$)?(?:lld|@)", key) == re.findall(r"%(?:\d+\$)?(?:lld|@)", unit["value"]), (key,language)
for source in (ROOT / "Sources").rglob("*.swift"):
    text=source.read_text()
    assert "@unchecked" not in text, source
    assert "Bundle(identifier:" not in text, source
    assert '"/bin/bash"' not in text, source
    assert "_CFBundleFlushBundleCaches" not in text, source
# Keep application policy independently importable by the future CLI and tests.
for layer in ["LatestCore", "LatestApplication"]:
    for source in (ROOT / "Sources" / layer).glob("*.swift"):
        assert not re.search(r"^import (?:AppKit|SwiftUI|Sparkle|LatestPlatform)\b", source.read_text(), re.MULTILINE), source
info=(ROOT / "Config/Info.plist").read_text()
assert "NSAllowsArbitraryLoads" not in info and "max.codes" not in info and "DSAKey" not in info
for path in (ROOT / "Config").glob("*.plist"):
    subprocess.run(["plutil","-lint",str(path)],check=True,capture_output=True)
subprocess.run(["plutil","-lint",str(ROOT/"Latest.xcodeproj/project.pbxproj")],check=True,capture_output=True)
ET.parse(ROOT/"Latest.xcodeproj/xcshareddata/xcschemes/Latest.xcscheme")
for source in (ROOT/"scripts").glob("*.py"):
    compile(source.read_text(),str(source),"exec")
print(f"Validated {len(catalogue['strings'])} English/German keys, project syntax and source boundaries.")
