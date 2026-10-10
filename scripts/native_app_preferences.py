#!/usr/bin/env python3
"""Exercise ignore/skip/version and instance-scoped channel preferences in native UI."""
import argparse
import copy
import hashlib
import json
import plistlib
import shutil
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture
from native_sparkle_compatibility import sign

ROOT = fixtures.ROOT
REPO = fixtures.REPO
NS = fixtures.NAMESPACE


def prepare_next_item(original):
    prepared = ROOT / 'evidence/l16/prepared' / uuid.uuid4().hex
    prepared.mkdir(parents=True, exist_ok=True)
    target = prepared / 'Latest Sparkle Fixture.app'
    shutil.copytree(ROOT / 'versions/sparkle/1.1.0/Latest Sparkle Fixture.app', target)
    info_path = target / 'Contents/Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info.update(CFBundleShortVersionString='1.2.0', CFBundleVersion='3')
    info_path.write_bytes(plistlib.dumps(info)); sign(target)
    archive = ROOT / 'web' / f'L16-next-{prepared.name}.zip'
    fixtures.run(['ditto', '-c', '-k', '--keepParent', target, archive])
    tool = REPO / '.build/debug/LatestRelease'
    item = copy.deepcopy(ET.fromstring(original).find('./channel/item'))
    item.find('title').text = 'Fixture 1.2.0'
    enclosure = item.find('enclosure')
    parsed = urlsplit(enclosure.get('url'))
    enclosure.set('url', urlunsplit((parsed.scheme, parsed.netloc, '/' + archive.name, '', '')))
    enclosure.set('length', str(archive.stat().st_size))
    enclosure.set(f'{{{NS}}}version', '3')
    enclosure.set(f'{{{NS}}}shortVersionString', '1.2.0')
    enclosure.set(f'{{{NS}}}edSignature', fixtures.run([tool, 'sign', ROOT / 'private/fixture-ed25519.key', archive], capture=True))
    return item, prepared


def write_feed(tree, prepared):
    unsigned = prepared / 'unsigned.xml'
    unsigned.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    fixtures.run([REPO / '.build/debug/LatestRelease', 'sign-feed', ROOT / 'private/fixture-ed25519.key', unsigned, ROOT / 'web/appcast.xml'])


def run_case(case):
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected)
    reset_sparkle(selected); reset_sparkle(other)
    controls = [selected, other, ROOT / 'applications/Latest Homebrew Fixture.app']
    before = [digest_app(app) for app in controls]
    feed = ROOT / 'web/appcast.xml'
    original = feed.read_bytes()
    item, prepared = prepare_next_item(original)
    state = ROOT / 'preferences/l03'
    state.mkdir(parents=True, exist_ok=True)
    preferences = state / 'preferences.json'
    preferences.write_text(json.dumps({'directories': [{'path': str(ROOT / 'applications'), 'enabled': True}], 'showIgnored': True}))
    journal = state / 'job-events.jsonl'
    journal.write_text('')
    evidence = ROOT / 'evidence/l16' / case
    name = 'NEXT' if case == 'ignore-skip' else 'CHANNELS'
    marker = ROOT / f'evidence/l16/{name}-ready'
    marker.parent.mkdir(parents=True, exist_ok=True)
    if marker.exists():
        marker.unlink()
    checkpoint = {}
    if case == 'channels':
        tree = ET.fromstring(original)
        ET.SubElement(item, f'{{{NS}}}channel').text = 'beta'
        tree.find('channel').insert(1, item)
        write_feed(tree, prepared)

    def coordinate(log):
        if f'L16_READY_{name}' in log and not marker.exists():
            value = json.loads(preferences.read_text())
            if case == 'ignore-skip':
                expected = str(selected) + '|sparkle|1.1.0 (2)'
                if value.get('skippedVersions') != {str(selected): expected} or value.get('ignoredBundleIDs'):
                    raise ValueError('Native skip/ignore state does not match the exact selected version/instance.')
                tree = ET.fromstring(original)
                channel = tree.find('channel')
                channel.remove(channel.find('item')); channel.append(item)
                write_feed(tree, prepared)
            elif value.get('channels') != {str(selected): 'beta'}:
                raise ValueError('Channel changed for an unselected instance or did not persist.')
            checkpoint.update(value)
            marker.write_text('Controlled next feed/state check complete.\n')

    test = 'testNativeIgnoreSkipAndNewVersion' if case == 'ignore-skip' else 'testNativeChannelsAreInstanceScopedAndPersistent'
    try:
        outcome = run_native_test(test, evidence, coordinate=coordinate)
    finally:
        feed.write_bytes(original)
    value = json.loads(preferences.read_text())
    if not checkpoint:
        raise ValueError('The actual native preference checkpoint did not execute.')
    if case == 'channels' and value.get('channels') != {str(selected): 'stable'}:
        raise ValueError('Returning to Stable did not persist for only the selected instance.')
    if any(digest_app(app) != expected for app, expected in zip(controls, before)) or journal.read_text().strip():
        raise ValueError('Preference checks must not install or mutate any controlled bundle.')
    result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                   xcode=fixtures.run(['xcodebuild', '-version'], capture=True), hostArchitecture='arm64'),
                  sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [REPO / 'Sources/LatestApp/AppModel.swift', REPO / 'Sources/LatestApp/AppDetail.swift',
                                             REPO / 'Sources/LatestPlatform/SparkleProvider.swift', REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]},
                  selectedPath=str(selected), otherPath=str(other), checkpoint=checkpoint,
                  finalPreferences=value, nativeTest=test, **outcome, allBundlesUnchanged=True, noInstallationJob=True)
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Native app preferences {case}: passed; persisted state and unchanged signed instances.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['ignore-skip', 'channels', 'all'])
    args = parser.parse_args()
    fixtures.run(['swift', 'build', '--product', 'LatestRelease'])
    for case in (['ignore-skip', 'channels'] if args.case == 'all' else [args.case]):
        run_case(case)
