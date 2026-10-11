#!/usr/bin/env python3
"""Drive real Sparkle lifecycle gates through ApplicationSession, without GUI automation."""
import argparse
import hashlib
import http.server
import json
import os
import plistlib
import signal
import ssl
import subprocess
import threading
import time
import xml.etree.ElementTree as ET
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture

ROOT = fixtures.ROOT
REPO = fixtures.REPO
TEST = 'realSparkleLifecycleWithoutGUIAutomation'


def execute(arguments, environment, log_path, coordinate=None):
    with log_path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 240
        try:
            while process.poll() is None:
                if time.monotonic() >= deadline: raise TimeoutError('The actual native lifecycle test exceeded its deadline.')
                if coordinate: coordinate()
                time.sleep(0.05)
        finally:
            if process.poll() is None:
                try: os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError: pass
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    try: os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError: pass
                    process.wait()
    text = log_path.read_text()
    if process.returncode or f'{TEST}() passed' not in text:
        print(text[-7000:]); raise ValueError('The required real lifecycle test did not pass; skips are not evidence.')


def run_case(case):
    fixtures.manifest()
    fixtures.run(['security', 'verify-cert', '-c', ROOT / 'tls.crt', '-p', 'ssl', '-n', 'localhost', '-L'], capture=True)
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    stop_selected_fixture(selected)
    reset_sparkle(selected); reset_sparkle(other)
    before = digest_app(selected)
    controls = [other, ROOT / 'applications/Latest Homebrew Fixture.app', ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    before_controls = {str(path): digest_app(path) for path in controls}
    state = ROOT / 'preferences/headless-lifecycle'; state.mkdir(parents=True, exist_ok=True)
    journal = state / 'job-events.jsonl'; journal.write_text('')
    evidence = ROOT / 'evidence/headless-lifecycle' / case; evidence.mkdir(parents=True, exist_ok=True)
    coordination = ROOT / 'evidence/headless-lifecycle/coordination'; coordination.mkdir(parents=True, exist_ok=True)
    for phase in ['fixture-ready', 'cancellation', 'download-error', 'handoff']:
        for suffix in ['ready', 'released']:
            path = coordination / f'{phase}-{suffix}'
            if path.exists(): path.unlink()
    feed = ROOT / 'web/appcast.xml'; original_feed = feed.read_bytes()
    archive = ROOT / 'web/LatestSparkleFixture-1.1.0.zip'
    requested = threading.Event(); released = threading.Event(); disconnected = threading.Event()
    transport = []
    checkpoint = {}
    fixture = None
    stopped = False

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_GET(self):
            if self.path != '/update.zip': self.send_error(404); return
            requested.set()
            if case == 'download-error':
                transport.append(dict(path=self.path, status=503)); self.send_error(503, 'Controlled actual download failure'); return
            data = archive.read_bytes()
            transport.append(dict(path=self.path, status=200, total=len(data), gatedBytes=1024))
            self.send_response(200); self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Length', str(len(data))); self.end_headers()
            try:
                self.wfile.write(data[:1024]); self.wfile.flush()
                released.wait(100)
                self.wfile.write(data[1024:]); self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError): disconnected.set()

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(ROOT / 'tls.crt', ROOT / 'private/tls.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    tree = ET.fromstring(original_feed)
    tree.find('./channel/item/enclosure').set('url', f'https://localhost:{server.server_port}/update.zip')
    feed.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    environment = fixtures.brew_environment(); environment['LATEST_HEADLESS_SPARKLE_LIFECYCLE'] = case

    def coordinate():
        nonlocal stopped
        if case == 'handoff' and requested.is_set(): released.set()
        for phase in ['fixture-ready', case]:
            ready, acknowledgement = coordination / f'{phase}-ready', coordination / f'{phase}-released'
            if not ready.exists() or acknowledgement.exists(): continue
            if phase == 'fixture-ready':
                if fixture is None or fixture.poll() is not None: raise ValueError('The selected real app did not stay running.')
                os.kill(fixture.pid, signal.SIGSTOP); stopped = True
                checkpoint['actualRegisteredFixturePID'] = fixture.pid
            else:
                if not requested.is_set(): raise ValueError('The actual gated HTTPS request never occurred.')
                if digest_app(selected) != before: raise ValueError('Before recovery/handoff the selected app already changed.')
                checkpoint['selectedUnchangedAtCheckpoint'] = True
                checkpoint['eventsBeforeRecovery'] = [json.loads(line) for line in journal.read_text().splitlines()]
                feed.write_bytes(original_feed)
                released.set()
                if case == 'handoff':
                    status = fixtures.run(['ps', '-p', str(fixture.pid), '-o', 'stat='], capture=True)
                    if 'T' not in status: raise ValueError('The actual app was not stopped at installer handoff.')
                    checkpoint['handoffCancellationIgnored'] = True
                    os.kill(fixture.pid, signal.SIGCONT); stopped = False
            acknowledgement.write_text('Verified real native checkpoint; recovery/handoff may continue.\n')

    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build', '--enable-swift-testing', '--disable-xctest', '--filter', TEST]
    try:
        if case == 'handoff':
            fixture = subprocess.Popen([str(selected / 'Contents/MacOS/FixtureApp')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            environment['LATEST_HEADLESS_HANDOFF_PID'] = str(fixture.pid)
        execute(arguments, environment, evidence / 'test.log', coordinate)
        if not requested.is_set() or not checkpoint.get('selectedUnchangedAtCheckpoint'):
            raise ValueError('Required actual transport/lifecycle checkpoint is missing.')
        feed.write_bytes(original_feed); released.set()
        restart_environment = dict(environment, LATEST_HEADLESS_SPARKLE_LIFECYCLE='checked')
        execute(arguments, restart_environment, evidence / 'restart.log')
        info = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
        if info['CFBundleShortVersionString'] != '1.1.0': raise ValueError('Actual signed recovery/handoff target was not installed.')
        fixtures.run(['codesign', '--verify', '--deep', '--strict', selected])
        arch = fixtures.run(['lipo', '-archs', selected / 'Contents/MacOS/FixtureApp'], capture=True)
        if arch != 'arm64': raise ValueError('Unexpected installed executable architecture.')
        for control in controls:
            if digest_app(control) != before_controls[str(control)]: raise ValueError('An unrelated instance changed.')
        events = [json.loads(line) for line in journal.read_text().splitlines()]
        jobs = {}
        for event in events:
            if event['path'] != str(selected): raise ValueError('A lifecycle job addressed another instance.')
            jobs.setdefault(event['job'], []).append(event['phase'])
        terminals = [[phase for phase in phases if phase in ['succeeded', 'failed', 'cancelled']] for phases in jobs.values()]
        expected = [['succeeded']] if case == 'handoff' else [['cancelled' if case == 'cancellation' else 'failed'], ['succeeded']]
        if terminals != expected: raise ValueError(f'Unexpected real terminal outcomes: {terminals}')
        sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
                   for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
        sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'scripts/native_fixtures.py', Path(__file__)]
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      environment={name: fixtures.run(command, capture=True) for name, command in
                                   [('macOS', ['sw_vers', '-productVersion']), ('Xcode', ['xcodebuild', '-version']),
                                    ('Swift', ['swift', '--version']), ('architecture', ['uname', '-m'])]},
                      transport=transport, checkpoint=checkpoint, cancelledTransportDisconnected=disconnected.is_set(),
                      jobPhases=list(jobs.values()), selectedPath=str(selected), installedVersion='1.1.0', actualArchitecture=arch,
                      signatureVerified=True, newProcessRestartVerified=True, controlsUnchanged=True, GUIAutomation=False)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Headless native lifecycle {case}: passed; actual terminal outcomes {terminals}; signed 1.1.0 and new process restart.')
    finally:
        feed.write_bytes(original_feed); released.set()
        server.shutdown(); server.server_close()
        if fixture and fixture.poll() is None:
            if stopped: os.kill(fixture.pid, signal.SIGCONT)
            fixture.terminate()
            try: fixture.wait(timeout=10)
            except subprocess.TimeoutExpired: fixture.kill(); fixture.wait()
        stop_selected_fixture(selected)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['cancellation', 'download-error', 'handoff', 'all'])
    args = parser.parse_args()
    for case in (['cancellation', 'download-error', 'handoff'] if args.case == 'all' else [args.case]): run_case(case)
