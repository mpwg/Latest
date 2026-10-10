#!/usr/bin/env python3
"""Exercise real Sparkle cancellation, download failure, retry and installer handoff."""
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
import xml.etree.ElementTree as ET
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test
from native_sparkle_acceptance import reset_sparkle

ROOT = fixtures.ROOT
REPO = fixtures.REPO


def run_case(case):
    selected = ROOT / 'applications/Latest Sparkle Fixture.app'
    other = ROOT / 'applications/Secondary/Latest Sparkle Fixture.app'
    reset_sparkle(selected); reset_sparkle(other)
    controls = [other, ROOT / 'applications/Latest Homebrew Fixture.app']
    before = digest_app(selected)
    control_before = [digest_app(app) for app in controls]
    feed = ROOT / 'web/appcast.xml'
    original_feed = feed.read_bytes()
    archive = ROOT / 'web/LatestSparkleFixture-1.1.0.zip'
    journal = ROOT / 'preferences/l03/job-events.jsonl'
    journal.parent.mkdir(parents=True, exist_ok=True)
    journal.write_text('')
    (journal.parent / 'preferences.json').write_text(json.dumps({'directories': [{'path': str(ROOT / 'applications'), 'enabled': True}]}))
    release_download = threading.Event()
    requested = threading.Event()
    disconnected = threading.Event()
    fixture_process = None
    checkpoint = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path != '/update.zip':
                self.send_error(404); return
            requested.set()
            if case == 'download-error':
                self.send_error(503, 'Controlled fixture download failure'); return
            data = archive.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            try:
                self.wfile.write(data[:1024]); self.wfile.flush()
                release_download.wait(90)
                self.wfile.write(data[1024:]); self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                disconnected.set()

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(ROOT / 'tls.crt', ROOT / 'private/tls.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    tree = ET.fromstring(original_feed)
    tree.find('./channel/item/enclosure').set('url', f'https://localhost:{server.server_port}/update.zip')
    feed.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    evidence = ROOT / 'evidence/l06' / case
    marker_name = {'cancellation': 'CANCEL_RETRY', 'download-error': 'FAIL_RETRY', 'handoff': 'HANDOFF'}[case]
    marker = ROOT / f'evidence/l06/{marker_name}-ready'
    marker.parent.mkdir(parents=True, exist_ok=True)
    if marker.exists():
        marker.unlink()

    def coordinate(log):
        if case == 'handoff' and requested.is_set():
            release_download.set()
        if f'L06_READY_{marker_name}' in log and not marker.exists():
            if case != 'handoff':
                if digest_app(selected) != before:
                    raise ValueError('Cancelled/failed download changed the selected app.')
                checkpoint.update(selectedUnchanged=True, events=[json.loads(line) for line in journal.read_text().splitlines()])
                feed.write_bytes(original_feed)
                release_download.set()
            elif fixture_process:
                os.kill(fixture_process.pid, signal.SIGCONT)
                checkpoint['cancellationDisabledAtHandoff'] = True
            marker.write_text('Fixture restored; native retry may proceed.\n')

    tests = {'cancellation': 'testNativeSparkleCancellationThenRetry',
             'download-error': 'testNativeSparkleDownloadFailureThenRetry',
             'handoff': 'testNativeSparkleHandoffDisablesCancel'}
    try:
        if case == 'handoff':
            import time
            fixture_process = subprocess.Popen([str(selected / 'Contents/MacOS/FixtureApp')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(2)
            if fixture_process.poll() is not None:
                raise ValueError('Controlled running fixture failed to launch.')
            os.kill(fixture_process.pid, signal.SIGSTOP)
        outcome = run_native_test(tests[case], evidence, coordinate=coordinate)
    finally:
        feed.write_bytes(original_feed)
        release_download.set()
        server.shutdown(); server.server_close()
        if fixture_process and fixture_process.poll() is None:
            os.kill(fixture_process.pid, signal.SIGCONT)
            fixture_process.terminate()
            fixture_process.wait(timeout=10)
        if case == 'handoff':
            # Sparkle can relaunch the updated disposable app with a different PID.
            executable = str(selected / 'Contents/MacOS/FixtureApp')
            for line in fixtures.run(['ps', '-axww', '-o', 'pid=,command='], capture=True).splitlines():
                pid, command = line.strip().split(None, 1)
                if command == executable:
                    try:
                        os.kill(int(pid), signal.SIGTERM)
                    except ProcessLookupError:
                        pass
    if not requested.is_set() or not checkpoint:
        raise ValueError('Native download/checkpoint did not execute.')
    info = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString'] != '1.1.0':
        raise ValueError('Actual successful retry/handoff did not install the target.')
    fixtures.run(['codesign', '--verify', '--deep', '--strict', selected])
    if any(digest_app(app) != expected for app, expected in zip(controls, control_before)):
        raise ValueError('Unrelated fixture changed.')
    events = [json.loads(line) for line in journal.read_text().splitlines()]
    jobs = {}
    for entry in events:
        if entry['path'] == str(selected):
            jobs.setdefault(entry['job'], []).append(entry['phase'])
    expected_terminals = ['succeeded'] if case == 'handoff' else [('cancelled' if case == 'cancellation' else 'failed'), 'succeeded']
    terminals = [[phase for phase in phases if phase in ['succeeded', 'failed', 'cancelled']] for phases in jobs.values()]
    if terminals != [[terminal] for terminal in expected_terminals]:
        raise ValueError(f'Expected exactly one terminal result per actual job: {terminals}')
    result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                   xcode=fixtures.run(['xcodebuild', '-version'], capture=True), architecture='arm64'),
                  sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [REPO / 'Sources/LatestPlatform/SparkleProvider.swift', REPO / 'Sources/LatestApp/AppModel.swift',
                                             REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]},
                  nativeTest=tests[case], **outcome, checkpoint=checkpoint, jobPhases=list(jobs.values()),
                  unrelatedFixturesUnchanged=True, installedVersion=info['CFBundleShortVersionString'], downloadRequested=True,
                  cancelledTransportDisconnected=disconnected.is_set())
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Native Sparkle {case}: passed; exact terminal results {terminals}; signed 1.1.0 and unchanged controls.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['cancellation', 'download-error', 'handoff', 'all'])
    args = parser.parse_args()
    for case in (['cancellation', 'download-error', 'handoff'] if args.case == 'all' else [args.case]):
        run_case(case)
