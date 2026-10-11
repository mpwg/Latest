#!/usr/bin/env python3
"""Exercise real major confirmation and bulk eligibility with signed native apps."""
import argparse
import copy
import hashlib
import http.server
import json
import plistlib
import shutil
import ssl
import threading
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlsplit
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture
from native_sparkle_compatibility import sign

ROOT = fixtures.ROOT
REPO = fixtures.REPO
NS = fixtures.NAMESPACE


def signed_feed(item, prepared, name):
    tree = ET.Element('rss', version='2.0')
    channel = ET.SubElement(tree, 'channel')
    ET.SubElement(channel, 'title').text = 'Latest controlled major/bulk fixtures'
    channel.append(item)
    unsigned = prepared / (name + '-unsigned.xml')
    signed = prepared / (name + '.xml')
    unsigned.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    fixtures.run([REPO / '.build/debug/LatestRelease', 'sign-feed', ROOT / 'private/fixture-ed25519.key', unsigned, signed])
    return signed.read_bytes()


def make_target(baseline, prepared, identifier, name, version, build, feed_url, minimum='27.0'):
    target = prepared / identifier / 'Latest Sparkle Fixture.app'
    shutil.copytree(baseline, target)
    path = target / 'Contents/Info.plist'
    info = plistlib.loads(path.read_bytes())
    info.update(CFBundleIdentifier=identifier, CFBundleName=name, CFBundleShortVersionString=version,
                CFBundleVersion=str(build), SUFeedURL=feed_url, LSMinimumSystemVersion=minimum)
    path.write_bytes(plistlib.dumps(info)); sign(target)
    archive = prepared / (identifier + '.zip')
    fixtures.run(['ditto', '-c', '-k', '--keepParent', target, archive])
    signature = fixtures.run([REPO / '.build/debug/LatestRelease', 'sign', ROOT / 'private/fixture-ed25519.key', archive], capture=True)
    return archive, signature


def run_case(case, test_runner=None, evidence_directory='l17', state_directory='l03'):
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    homebrew = ROOT / 'applications/Latest Homebrew Fixture.app'
    stop_selected_fixture(selected)
    reset_sparkle(selected); reset_sparkle(other)
    feed_path = ROOT / 'web/appcast.xml'
    original_feed = feed_path.read_bytes()
    template = ET.fromstring(original_feed).find('./channel/item')
    prepared = ROOT / 'evidence' / evidence_directory / 'prepared' / uuid.uuid4().hex
    prepared.mkdir(parents=True, exist_ok=True)
    group = ROOT / 'applications' / ('L17-' + prepared.name)
    baseline = ROOT / 'versions/sparkle/1.0.0/Latest Sparkle Fixture.app'
    controls = [other, homebrew, ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    targets = {'selected': selected}
    payloads = {}
    request_counts = {}
    download_gate = threading.Event()
    scan_gate = threading.Event()
    checkpoint = {}
    state = ROOT / 'preferences' / state_directory
    state.mkdir(parents=True, exist_ok=True)
    journal = state / 'job-events.jsonl'
    journal.write_text('')

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            path = urlsplit(self.path).path
            request_counts[path] = request_counts.get(path, 0) + 1
            if path == '/scan-gate.xml':
                if test_runner is not None:
                    (evidence / 'scan-requested').write_text('Actual HTTPS scan request received.\n')
                scan_gate.wait(45)
            data = payloads.get(path)
            if data is None:
                self.send_error(404); return
            self.send_response(200)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Content-Type', 'application/octet-stream' if path.endswith('.zip') else 'application/xml')
            self.end_headers()
            try:
                if case == 'bulk' and path in ['/selected.zip', '/minor.zip']:
                    self.wfile.write(data[:1024]); self.wfile.flush()
                    download_gate.wait(90)
                    self.wfile.write(data[1024:])
                else:
                    self.wfile.write(data)
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                pass

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(ROOT / 'tls.crt', ROOT / 'private/tls.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    origin = f'https://localhost:{server.server_port}'
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    evidence = ROOT / 'evidence' / evidence_directory / case
    evidence.mkdir(parents=True, exist_ok=True)
    if (evidence / 'scan-requested').exists(): (evidence / 'scan-requested').unlink()
    markers = ['SCAN', 'BULK'] if case == 'bulk' else (['CHANGED_MAJOR'] if case == 'changed-major' else ['CANCEL_MAJOR'])
    for name in markers:
        path = ROOT / 'evidence' / evidence_directory / (name + '-ready')
        if path.exists():
            path.unlink()

    try:
        version = '2.0.0' if case == 'major' else '1.1.0'
        archive, signature = make_target(baseline, prepared, fixtures.manifest()['fixtures'][0]['bundleID'],
                                         'Latest Sparkle Fixture', version, 2,
                                         plistlib.loads((baseline / 'Contents/Info.plist').read_bytes())['SUFeedURL'])
        payloads['/selected.zip'] = archive.read_bytes()
        item = copy.deepcopy(template)
        enclosure = item.find('enclosure')
        enclosure.set('url', origin + '/selected.zip'); enclosure.set('length', str(archive.stat().st_size))
        enclosure.set(f'{{{NS}}}shortVersionString', version); enclosure.set(f'{{{NS}}}version', '2')
        enclosure.set(f'{{{NS}}}edSignature', signature)
        if case == 'provider-major':
            ET.SubElement(item, f'{{{NS}}}minimumAutoupdateVersion').text = '2'
        feed_path.write_bytes(signed_feed(item, prepared, 'selected'))
        preferences = dict(directories=[dict(path=str(ROOT / 'applications'), enabled=True)], showIgnored=True)
        if case == 'bulk':
            group.mkdir()
            skipped = {str(other): str(other) + '|sparkle|1.1.0 (2)'}
            ignored = []
            variants = [('minor', '1.1.0', 2, '27.0'), ('major', '2.0.0', 2, '27.0'), ('declared-major', '1.1.0', 2, '27.0'),
                        ('ignored', '1.1.0', 2, '27.0'), ('skipped', '1.1.0', 2, '27.0'),
                        ('incompatible', '1.1.0', 2, '99.0'), ('current', '1.0.0', 1, '27.0'),
                        ('unknown', '1.0.0', 1, '27.0')]
            for key, target_version, build, minimum in variants:
                identifier = 'io.github.mpwg.Latest.NativeFixture.L17.' + key
                name = 'Latest L17 ' + key.title() + ' Fixture'
                app = group / (name + '.app')
                shutil.copytree(baseline, app)
                info_path = app / 'Contents/Info.plist'
                info = plistlib.loads(info_path.read_bytes())
                url = origin + ('/scan-gate.xml' if key == 'current' else '/' + key + '.xml')
                info.update(CFBundleIdentifier=identifier, CFBundleName=name, SUFeedURL=url)
                if key == 'unknown':
                    info.pop('SUFeedURL'); info.pop('SUPublicEDKey')
                info_path.write_bytes(plistlib.dumps(info)); sign(app)
                targets[key] = app
                if key not in ['minor']:
                    controls.append(app)
                if key == 'ignored':
                    ignored.append(identifier)
                if key == 'skipped':
                    skipped[str(app)] = str(app) + '|sparkle|1.1.0 (2)'
                if key == 'unknown':
                    continue
                archive, signature = make_target(baseline, prepared, identifier, name, target_version, build, url, minimum)
                payloads['/' + key + '.zip'] = archive.read_bytes()
                item = copy.deepcopy(template)
                item.find(f'{{{NS}}}minimumSystemVersion').text = minimum
                if key == 'declared-major':
                    ET.SubElement(item, f'{{{NS}}}minimumAutoupdateVersion').text = '2'
                enclosure = item.find('enclosure')
                enclosure.set('url', origin + '/' + key + '.zip'); enclosure.set('length', str(archive.stat().st_size))
                enclosure.set(f'{{{NS}}}shortVersionString', target_version); enclosure.set(f'{{{NS}}}version', str(build))
                enclosure.set(f'{{{NS}}}edSignature', signature)
                payloads['/scan-gate.xml' if key == 'current' else '/' + key + '.xml'] = signed_feed(item, prepared, key)
            preferences.update(ignoredBundleIDs=ignored, skippedVersions=skipped)
        (state / 'preferences.json').write_text(json.dumps(preferences))
        before_controls = [digest_app(app) for app in controls]
        before_targets = {key: digest_app(app) for key, app in targets.items() if key in ['selected', 'minor']}
        (evidence / 'paths.json').write_text(json.dumps({key: str(app) for key, app in targets.items()}, indent=2) + '\n')

        def coordinate(log):
            for name in markers:
                marker = ROOT / 'evidence' / evidence_directory / (name + '-ready')
                if f'L17_READY_{name}' in log and not marker.exists():
                    events = [json.loads(line) for line in journal.read_text().splitlines()]
                    if any(digest_app(targets[key]) != expected for key, expected in before_targets.items()):
                        raise ValueError('A target changed before native consent/gated bulk release.')
                    if name in ['CANCEL_MAJOR', 'CHANGED_MAJOR', 'SCAN'] and events:
                        raise ValueError('Cancellation/active scan started an unauthorized job.')
                    if name == 'SCAN':
                        if not request_counts.get('/scan-gate.xml'):
                            raise ValueError('The actual provider scan did not reach its controlled gate.')
                        scan_gate.set()
                    elif name == 'CHANGED_MAJOR':
                        changed = ET.fromstring(feed_path.read_bytes()).find('./channel/item')
                        ET.SubElement(changed, f'{{{NS}}}minimumAutoupdateVersion').text = '2'
                        feed_path.write_bytes(signed_feed(changed, prepared, 'changed-major'))
                    elif name == 'BULK':
                        expected_paths = {str(targets[key]) for key in ['selected', 'minor']}
                        jobs = {entry['path']: entry['job'] for entry in events if entry['phase'] == 'checking'}
                        if set(jobs) != expected_paths or len({entry['job'] for entry in events}) != 2:
                            raise ValueError('Bulk/duplicate activation did not create exactly the two authorized jobs.')
                        download_gate.set()
                    checkpoint[name] = events
                    marker.write_text('Native gated checkpoint verified.\n')

        tests = dict(major='testNativeMajorConsentAndCancellation', bulk='testNativeBulkEligibilityAndDuplicateActivation',
                     **{'provider-major': 'testNativeProviderDeclaredMajorConsent', 'changed-major': 'testNativeChangedMajorRequirementIsRejected'})
        test = tests[case]
        outcome = (test_runner or run_native_test)(test, evidence, coordinate=coordinate)
        if set(checkpoint) != set(markers):
            raise ValueError('Not every required actual native checkpoint executed.')
        expected_keys = ['selected', 'minor'] if case == 'bulk' else ['selected']
        events = [json.loads(line) for line in journal.read_text().splitlines()]
        jobs = {}
        for entry in events:
            jobs.setdefault(entry['job'], []).append(entry)
        if len(jobs) != len(expected_keys):
            raise ValueError('Repeated or unexpected bulk job.')
        if {entries[0]['path'] for entries in jobs.values()} != {str(targets[key]) for key in expected_keys}:
            raise ValueError('An unselected/excluded application reached the installer.')
        for entries in jobs.values():
            terminal = 'failed' if case == 'changed-major' else 'succeeded'
            if [entry['phase'] for entry in entries if entry['phase'] in ['succeeded', 'failed', 'cancelled']] != [terminal]:
                raise ValueError('Every authorized actual job must succeed exactly once.')
        installed = {}
        for key in expected_keys:
            app = targets[key]
            info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
            expected_version = '2.0.0' if case == 'major' else ('1.0.0' if case == 'changed-major' else '1.1.0')
            expected_build = '1' if case == 'changed-major' else '2'
            if info['CFBundleShortVersionString'] != expected_version or info['CFBundleVersion'] != expected_build:
                raise ValueError('Actual installed target version is wrong.')
            fixtures.run(['codesign', '--verify', '--deep', '--strict', app])
            architecture = fixtures.run(['lipo', '-archs', app / 'Contents/MacOS/FixtureApp'], capture=True)
            if architecture != 'arm64':
                raise ValueError('Actual installed executable architecture changed.')
            installed[key] = dict(path=str(app), bundleID=info['CFBundleIdentifier'], version=expected_version, build=expected_build, architecture=architecture)
        if case == 'changed-major' and (digest_app(selected) != before_targets['selected'] or request_counts.get('/selected.zip')):
            raise ValueError('Changed major consent must fail before downloading or mutating the selected app.')
        if any(digest_app(app) != expected for app, expected in zip(controls, before_controls)):
            raise ValueError('An excluded or unrelated controlled application changed.')
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                       xcode=fixtures.run(['xcodebuild', '-version'], capture=True), hostArchitecture='arm64'),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                    for path in [REPO / 'Sources/LatestApp/AppModel.swift', REPO / 'Sources/LatestApp/LatestWindow.swift',
                                                 REPO / 'Sources/LatestApp/AppDetail.swift', REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]},
                      nativeTest=outcome.get('testIdentifier', test), **outcome, checkpoints=checkpoint, installed=installed, jobEvents=events,
                      requestCounts=request_counts, excludedAndUnrelatedUnchanged=True,
                      retiredGroup=str(prepared / 'retired-installed-apps') if group.exists() else None)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Native {case}: passed; {len(jobs)} actual jobs with expected terminal results and unchanged excluded/control apps.')
        return result
    finally:
        feed_path.write_bytes(original_feed)
        scan_gate.set(); download_gate.set()
        server.shutdown(); server.server_close()
        if group.exists():
            shutil.move(group, prepared / 'retired-installed-apps')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['major', 'provider-major', 'changed-major', 'bulk', 'all'])
    args = parser.parse_args()
    fixtures.run(['swift', 'build', '--product', 'LatestRelease'])
    for case in (['major', 'provider-major', 'changed-major', 'bulk'] if args.case == 'all' else [args.case]):
        run_case(case)
