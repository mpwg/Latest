#!/usr/bin/env python3
"""Provide real gated HTTPS for interactive native acceptance; never automate the GUI."""
import argparse
import http.server
import json
import plistlib
import signal
import ssl
import threading
import time
import xml.etree.ElementTree as ET
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_sparkle_acceptance import reset_sparkle
from native_sparkle_lifecycle import stop_selected_fixture


def serve(name):
    if not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in name):
        raise ValueError('Use a simple private evidence name.')
    root = fixtures.ROOT
    fixtures.manifest()
    fixtures.run(['security', 'verify-cert', '-c', root / 'tls.crt', '-p', 'ssl', '-n', 'localhost', '-L'], capture=True)
    evidence = root / 'evidence/native-ui-lifecycle' / name
    if evidence.exists(): raise ValueError('Evidence already exists; preserve it and choose a new name.')
    evidence.mkdir(parents=True)
    selected = root / 'applications/Latest Sparkle Fixture.app'
    controls = [root / 'applications/Secondary/Latest Sparkle Fixture.app',
                root / 'applications/Latest Homebrew Fixture.app',
                root / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    before = {str(app): digest_app(app) for app in controls}
    stop_selected_fixture(selected)
    reset_sparkle(selected)
    selected_before = digest_app(selected)
    feed = root / 'web/appcast.xml'; original = feed.read_bytes()
    preferences = root / 'preferences/l03/preferences.json'; saved_preferences = preferences.read_bytes()
    journal = preferences.parent / 'job-events.jsonl'
    journal_before = journal.read_bytes() if journal.exists() else b''
    (evidence / 'before.json').write_text(json.dumps(dict(selected=str(selected), selectedBytes=selected_before,
                                                       controlBytes=before), indent=2) + '\n')
    (evidence / 'original-feed.xml').write_bytes(original)
    (evidence / 'original-preferences.json').write_bytes(saved_preferences)
    (evidence / 'original-journal.jsonl').write_bytes(journal_before)
    preferences.write_text(json.dumps(dict(directories=[dict(path=str(root / 'applications'), enabled=True)],
                                          showCurrent=True, showUnknown=True, showIgnored=True, fontScale=1.6)) + '\n')
    (evidence / 'mode').write_text('gated')
    archive = root / 'web/LatestSparkleFixture-1.1.0.zip'
    lock = threading.Lock()

    def record(**event):
        with lock:
            with (evidence / 'transport.jsonl').open('a') as log:
                log.write(json.dumps(dict(time=time.time(), **event)) + '\n')

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_GET(self):
            if self.path != '/update.zip': self.send_error(404); return
            mode = (evidence / 'mode').read_text().strip()
            if mode == 'error':
                record(path=self.path, status=503)
                self.send_error(503, 'Controlled native acceptance failure'); return
            data = archive.read_bytes()
            record(path=self.path, status=200, mode=mode, bytes=len(data))
            self.send_response(200); self.send_header('Content-Length', str(len(data)))
            self.send_header('Content-Type', 'application/octet-stream'); self.end_headers()
            try:
                self.wfile.write(data[:1024]); self.wfile.flush()
                (evidence / 'download-started').write_text('Actual HTTPS bytes flushed.\n')
                deadline = time.monotonic() + 600
                offset = 1024
                heartbeat = time.monotonic() + 5
                while mode == 'gated' and not (evidence / 'release').exists() and not (evidence / 'stop').exists():
                    if time.monotonic() >= deadline:
                        record(deadlineExpired=True); return
                    if time.monotonic() >= heartbeat:
                        self.wfile.write(data[offset:offset + 1]); self.wfile.flush()
                        offset += 1; heartbeat = time.monotonic() + 5
                        record(heartbeatBytes=offset)
                    time.sleep(0.1)
                self.wfile.write(data[offset:]); self.wfile.flush()
                record(delivered=True)
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError): record(disconnected=True)

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    server.daemon_threads = True; server.timeout = 0.5
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(root / 'tls.crt', root / 'private/tls.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    tree = ET.fromstring(original)
    tree.find('./channel/item/enclosure').set('url', f'https://localhost:{server.server_port}/update.zip')
    feed.write_bytes(ET.tostring(tree, encoding='utf-8', xml_declaration=True))
    (evidence / 'ready.json').write_text(json.dumps(dict(port=server.server_port, selected=str(selected),
                                                       sourceRevision=fixtures.run(['git','rev-parse','HEAD'], capture=True))) + '\n')
    print(f'Native UI transport ready: {evidence}; existing certificate/trust retained.', flush=True)
    signal.signal(signal.SIGTERM, lambda *_: (evidence / 'stop').touch())
    try:
        while not (evidence / 'stop').exists(): server.handle_request()
    finally:
        (evidence / 'release').touch(); server.server_close(); feed.write_bytes(original)
        # Restore only after the controlled GUI process has been quit by the operator.
        preferences.write_bytes(saved_preferences)
        for app, value in before.items():
            if digest_app(Path(app)) != value: raise ValueError('A nonselected instance changed.')
        info = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
        (evidence / 'after.json').write_text(json.dumps(dict(installedVersion=info['CFBundleShortVersionString'],
                                                            controlsUnchanged=True), indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('name')
    serve(parser.parse_args().name)
