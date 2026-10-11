#!/usr/bin/env python3
"""Exercise actual folder selection, persisted exclusions, ejection and late HTTPS scans."""
import argparse
import copy
import hashlib
import http.server
import json
import os
import plistlib
import shutil
import ssl
import subprocess
import threading
import uuid
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test
from native_sparkle_compatibility import sign
from native_major_bulk import signed_feed

ROOT = fixtures.ROOT
REPO = fixtures.REPO


def run_case(case, test_runner=None, evidence_directory='l19', state_directory='l03'):
    prepared = ROOT / 'evidence' / evidence_directory / 'prepared' / uuid.uuid4().hex
    prepared.mkdir(parents=True)
    evidence = ROOT / 'evidence' / evidence_directory / case
    evidence.mkdir(parents=True, exist_ok=True)
    markers = ['DISABLED', 'REMOVED', 'PERSISTED'] if case == 'actions' else (['HELD', 'LATE', 'SUPERSEDED'] if case == 'stale' else ['EJECT', 'REMOUNT', 'RECOVERED'])
    for name in markers:
        for suffix in ['ready', 'requested']:
            marker = ROOT / 'evidence' / evidence_directory / (name + '-' + suffix)
            if marker.exists(): marker.unlink()
    if (evidence / 'request-received').exists(): (evidence / 'request-received').unlink()
    controls = [ROOT / 'applications/Latest Sparkle Fixture.app', ROOT / 'applications/Secondary/Latest Sparkle Fixture.app',
                ROOT / 'applications/Latest Homebrew Fixture.app', ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    before_controls = [digest_app(app) for app in controls]
    mounted = False
    image = prepared / 'controlled-volume.dmg'
    mount = Path('/Volumes/Latest-L19-' + prepared.name)
    paths = {}
    checkpoints = {}
    gate = threading.Event()
    received = threading.Event()
    answered = threading.Event()
    transport = {}
    payload = None

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_GET(self):
            if self.path != '/held.xml': self.send_error(404); return
            received.set()
            if test_runner is not None:
                (evidence / 'request-received').write_text('Actual old-generation HTTPS request received.\n')
            gate.wait(120)
            try:
                self.send_response(200); self.send_header('Content-Length', str(len(payload))); self.end_headers()
                self.wfile.write(payload); self.wfile.flush()
                transport['oldResponse'] = 'sent after newer generation removed the app'
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                transport['oldResponse'] = 'transport closed by cancellation before delayed response'
            finally: answered.set()

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(ROOT / 'tls.crt', ROOT / 'private/tls.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    def attach():
        nonlocal mounted
        output = subprocess.run(['hdiutil', 'attach', str(image), '-nobrowse', '-mountpoint', str(mount), '-plist'], check=True, capture_output=True).stdout
        entities = plistlib.loads(output)['system-entities']
        if not any(entity.get('mount-point') == str(mount) for entity in entities) or not os.path.ismount(mount):
            raise ValueError('The disposable image did not mount at its exact controlled path.')
        mounted = True

    def detach():
        nonlocal mounted
        fixtures.run(['hdiutil', 'detach', mount])
        mounted = False
        if mount.exists(): raise ValueError('The ejected controlled volume path still exists.')

    def app_at(directory, kind, feed=None):
        app = directory / ('Latest L19 ' + kind + ' Fixture.app')
        shutil.copytree(ROOT / 'versions/sparkle/1.0.0/Latest Sparkle Fixture.app', app)
        info_path = app / 'Contents/Info.plist'
        info = plistlib.loads(info_path.read_bytes())
        info.update(CFBundleIdentifier='io.github.mpwg.Latest.NativeFixture.L19.' + kind, CFBundleName='Latest L19 ' + kind + ' Fixture')
        if feed: info['SUFeedURL'] = feed
        else:
            info.pop('SUFeedURL'); info.pop('SUPublicEDKey')
        info_path.write_bytes(plistlib.dumps(info)); sign(app)
        return app

    try:
        if case == 'actions':
            initial, added = prepared / 'initial', prepared / 'added'
            initial.mkdir(); added.mkdir()
            app_at(initial, 'Initial'); app_at(added, 'Added')
            paths.update(initial=str(initial), added=str(added))
            directories = [dict(path='/Applications', enabled=False), dict(path=str(Path.home() / 'Applications'), enabled=False), dict(path=str(initial), enabled=True)]
        else:
            fixtures.run(['hdiutil', 'create', '-size', '32m', '-fs', 'HFS+', '-volname', mount.name, image])
            attach()
            paths.update(volume=str(mount), empty='true' if case == 'empty-volume' else 'false')
            if case != 'empty-volume':
                app_at(mount, 'Volume', f'https://localhost:{server.server_port}/held.xml' if case == 'stale' else None)
            directories = [dict(path=str(mount), enabled=True)]
        if case == 'stale':
            import xml.etree.ElementTree as ET
            item = copy.deepcopy(ET.fromstring((ROOT / 'web/appcast.xml').read_bytes()).find('./channel/item'))
            payload = signed_feed(item, prepared, 'held')
        native_before = {str(app): digest_app(app) for directory in directories if directory['enabled']
                         for app in Path(directory['path']).glob('*.app')}
        if case == 'actions': native_before.update({str(app): digest_app(app) for app in added.glob('*.app')})
        (ROOT / 'evidence' / evidence_directory / 'paths.json').write_text(json.dumps(paths, indent=2) + '\n')
        state = ROOT / 'preferences' / state_directory
        state.mkdir(parents=True, exist_ok=True)
        preferences = state / 'preferences.json'
        preferences.write_text(json.dumps(dict(directories=directories)))
        journal = state / 'job-events.jsonl'; journal.write_text('')

        def coordinate(log):
            for name in markers:
                marker = ROOT / 'evidence' / evidence_directory / (name + '-ready')
                requested = ROOT / 'evidence' / evidence_directory / (name + '-requested')
                reached = f'L19_READY_{name}' in log or (test_runner is not None and requested.exists())
                if not reached or marker.exists(): continue
                current = json.loads(preferences.read_text())
                entries = current['directories']
                if name == 'DISABLED':
                    if any(entry['enabled'] for entry in entries): raise ValueError('Native folder disabling did not persist.')
                elif name in ['REMOVED', 'PERSISTED']:
                    if any(entry['path'] == paths['initial'] for entry in entries): raise ValueError('Removed folder persisted.')
                    if not any(entry['path'] == paths['added'] and entry['enabled'] for entry in entries): raise ValueError('The native panel selection did not persist.')
                    if any(entry['enabled'] for entry in entries if entry['path'] in ['/Applications', str(Path.home() / 'Applications')]):
                        raise ValueError('A disabled standard directory was enabled.')
                elif name == 'EJECT': detach()
                elif name == 'REMOUNT': attach()
                elif name == 'HELD':
                    if not received.wait(5): raise ValueError('The real provider did not reach the controlled HTTPS gate.')
                    detach()
                elif name == 'LATE':
                    if entries: raise ValueError('The newer scan did not persist the removed volume directory.')
                    gate.set()
                    if not answered.wait(5): raise ValueError('The held real HTTPS response did not finish.')
                elif name == 'SUPERSEDED': attach()
                checkpoints[name] = dict(directories=entries, mounted=mounted)
                marker.write_text('Actual native checkpoint verified.\n')

        test = {'actions': 'testNativeDirectoryActionsAndPersistence', 'stale': 'testNativeSupersededVolumeScanCannotRestoreRemovedApps',
                'volume': 'testNativeVolumeLossAndRecovery', 'empty-volume': 'testNativeVolumeLossAndRecovery'}[case]
        outcome = (test_runner or run_native_test)(test, evidence, coordinate=coordinate)
        if set(checkpoints) != set(markers): raise ValueError('A required actual native checkpoint is missing.')
        if any(digest_app(app) != expected for app, expected in zip(controls, before_controls)):
            raise ValueError('An unrelated controlled app changed.')
        if any(digest_app(Path(path)) != expected for path, expected in native_before.items()):
            raise ValueError('A scanned controlled bundle changed.')
        if journal.read_text(): raise ValueError('Directory acceptance unexpectedly started installation work.')
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True), xcode=fixtures.run(['xcodebuild', '-version'], capture=True), architecture='arm64'),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in
                                    [REPO / 'Sources/LatestPlatform/Inventory.swift', REPO / 'Sources/LatestApp/AppModel.swift', REPO / 'Sources/LatestApp/LatestSettings.swift', REPO / 'Sources/LatestApp/LatestWindow.swift', REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]},
                      paths=paths, checkpoints=checkpoints, transport=transport, nativeTest=outcome.get('testIdentifier', test), **outcome,
                      scannedBundlesUnchanged=True, unrelatedControlsUnchanged=True, noInstallJobs=True)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Native directories {case}: passed; actual directory/volume actions and unchanged bundles.')
        return result
    finally:
        gate.set(); server.shutdown(); server.server_close()
        if mounted: detach()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['actions', 'volume', 'empty-volume', 'stale', 'all'])
    args = parser.parse_args()
    for case in (['actions', 'volume', 'empty-volume', 'stale'] if args.case == 'all' else [args.case]): run_case(case)
