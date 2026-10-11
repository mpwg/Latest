#!/usr/bin/env python3
"""Run the actual core HTTPS/cache client against isolated native TLS endpoints."""
from pathlib import Path
import hashlib
import http.server
import json
import os
import platform
import socket
import ssl
import subprocess
import tempfile
import threading
import time
from datetime import datetime, timezone

REPO = Path(__file__).resolve().parent.parent
FIXTURES = REPO / '.build/native-install-tests'
CERTIFICATE_SHA256 = '1A896B83437CE7DD4491D216B88A4B1146C83D66EACBDE1A93D60C4A4E9F56CD'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def app_bytes():
    return {str(path.relative_to(FIXTURES)): digest(path)
            for path in (FIXTURES / 'applications').rglob('*') if path.is_file()}


def main():
    evidence = Path(tempfile.mkdtemp(prefix='run-', dir=make_evidence_directory()))
    original_apps = app_bytes()
    fingerprint = subprocess.check_output(['openssl', 'x509', '-in', str(FIXTURES / 'tls.crt'),
                                           '-noout', '-fingerprint', '-sha256'], text=True).strip().split('=')[1].replace(':', '')
    if fingerprint != CERTIFICATE_SHA256:
        raise ValueError('Reuse exactly the approved localhost certificate; do not rotate or alter trust.')
    executable = evidence / 'NetworkAcceptance'
    sources = sorted((REPO / 'Sources/LatestCore').glob('*.swift'))
    command = ['swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
               *map(str, sources), str(REPO / 'Tests/NativeFixtures/NetworkAcceptance.swift'), '-o', str(executable)]
    with (evidence / 'compile.log').open('w') as log:
        subprocess.run(command, cwd=REPO, check=True, stdout=log, stderr=subprocess.STDOUT)
    observations = []
    requests = []
    lock = threading.Lock()
    state = {'mode': 'valid'}
    servers = []

    def native(mode, port):
        command = [str(executable), mode, str(evidence), str(port)]
        result = subprocess.run(command, cwd=REPO, capture_output=True, text=True, timeout=75)
        (evidence / f'{mode}.stdout.log').write_text(result.stdout)
        (evidence / f'{mode}.stderr.log').write_text(result.stderr)
        if result.returncode:
            raise RuntimeError(f'Native {mode} failed ({result.returncode}): {result.stderr[-2000:]}')
        observation = json.loads(result.stdout)
        observations.append(observation)
        print(f'Native {mode}: {json.dumps(observation)}', flush=True)
        return observation

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *_):
            pass

        def handle(self):
            try:
                super().handle()
            except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                # Native certificate rejection/cancellation closes an owned TLS socket.
                pass

        def do_GET(self):
            with lock:
                mode = state['mode']
                record = dict(path=self.path, mode=mode, tls=isinstance(self.connection, ssl.SSLSocket),
                              sentBytes=0, chunks=0)
                requests.append(record)
            if self.path == '/redirect':
                self.send_response(302)
                self.send_header('Location', f'http://127.0.0.1:{port + 1}/unsafe')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            if self.path != '/resource':
                self.send_error(404)
                return
            if mode in ['stream', 'cancelled']:
                record['transferEncoding'] = 'chunked'
                record['contentLength'] = None
                self.send_response(200)
                self.send_header('Transfer-Encoding', 'chunked')
                self.end_headers()
                try:
                    body = valid_resource + b' ' * (80 * 1024 - len(valid_resource))
                    for offset in range(0, len(body), 1024):
                        data = body[offset:offset + 1024]
                        self.wfile.write(b'400\r\n' + data + b'\r\n')
                        self.wfile.flush()
                        with lock:
                            record['sentBytes'] += len(data)
                            record['chunks'] += 1
                        if mode == 'cancelled':
                            (evidence / 'stream-started').touch()
                            time.sleep(0.1)
                    self.wfile.write(b'0\r\n\r\n')
                except (BrokenPipeError, ConnectionResetError, ssl.SSLError):
                    record['clientDisconnected'] = True
                return
            data = b'invalid json' if mode == 'invalid' else valid_resource
            self.send_response(503 if mode == 'status' else 200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            with lock:
                record['sentBytes'] = len(data)

    class IPv6Server(http.server.ThreadingHTTPServer):
        address_family = socket.AF_INET6

    try:
        # The real current catalogue is fetched by the production client, not curl.
        native('sample', 8454)
        sample = json.loads((evidence / 'provider-sample.json').read_text())
        if not isinstance(sample, list) or len(sample) < 2:
            raise ValueError('The actual current provider response has an unexpected shape.')
        neighbours = [sample[0], {'token': '--malformed', 'version': '2'}, None,
                      sample[1], {'token': 'no-version'}, 'invalid neighbour']
        valid_resource = json.dumps({'casks': neighbours}).encode()
        if len(valid_resource) >= 65_536:
            raise ValueError('Selected real neighbours exceed the controlled response bound.')
        (evidence / 'valid-resource.json').write_bytes(valid_resource)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(FIXTURES / 'tls.crt', FIXTURES / 'private/tls.key')
        for port in range(8454, 8495, 2):
            attempt = []
            try:
                attempt.append(http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler))
                attempt.append(IPv6Server(('::1', port), Handler))
                attempt.append(http.server.ThreadingHTTPServer(('127.0.0.1', port + 1), Handler))
            except OSError:
                for server in attempt:
                    server.server_close()
                continue
            servers = attempt
            break
        else:
            raise ValueError('No isolated loopback test port pair is available.')
        for server in servers[:2]:
            server.socket = context.wrap_socket(server.socket, server_side=True)
        for server in servers:
            threading.Thread(target=server.serve_forever, daemon=True).start()
        native('valid', port)
        endpoint = f'https://localhost:{port}/resource'
        cache = evidence / 'cache' / (hashlib.sha256(endpoint.encode()).hexdigest() + '.json')
        expected_cache = cache.read_bytes()
        expected_mtime = cache.stat().st_mtime_ns
        for mode in ['certificate', 'redirect', 'status', 'invalid', 'stream', 'stream-limit', 'cancelled']:
            state['mode'] = 'stream' if mode == 'stream-limit' else mode
            native(mode, port)
            if cache.read_bytes() != expected_cache or cache.stat().st_mtime_ns != expected_mtime:
                raise ValueError(f'{mode} changed the last-known-good cache.')
        for server in servers[:2]:
            server.shutdown()
            server.server_close()
        active_servers = servers[2:]
        servers = active_servers
        native('offline', port)
        if cache.read_bytes() != expected_cache or cache.stat().st_mtime_ns != expected_mtime:
            raise ValueError('Actual connection failure changed the good cache.')
        os.utime(cache, (time.time() - 8 * 86400, time.time() - 8 * 86400))
        native('expired', port)
        cache.write_bytes(b'invalid json')
        native('corrupt', port)
        cache.write_bytes(b'x' * 65_537)
        native('oversized-cache', port)
        cache.write_bytes(expected_cache)
        os.utime(cache, ns=(expected_mtime, expected_mtime))
        if any(not request['tls'] for request in requests):
            raise ValueError('The HTTPS downgrade reached the plain-HTTP trap.')
        streamed = [request for request in requests if request['mode'] == 'stream']
        if len(streamed) != 2 or any(request['sentBytes'] <= 65_536 or request['chunks'] <= 1 for request in streamed):
            raise ValueError('The actual unknown-length response did not cross the streamed bound.')
        if app_bytes() != original_apps:
            raise ValueError('A controlled application instance changed during read-only network acceptance.')
        source_paths = [*sources, REPO / 'Tests/NativeFixtures/NetworkAcceptance.swift', Path(__file__)]
        result = dict(format=1, observedAt=datetime.now(timezone.utc).isoformat(),
                      sourceRevision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip(),
                      sourceSHA256={str(path.relative_to(REPO)): digest(path) for path in source_paths},
                      environment=dict(macOS=platform.mac_ver()[0], architecture=platform.machine(),
                                       swift=subprocess.check_output(['swift', '--version'], text=True).strip()),
                      observations=observations, requests=requests, providerSampleURL='https://formulae.brew.sh/api/cask.json',
                      providerSampleSHA256=digest(evidence / 'provider-sample.json'),
                      certificateSHA256=fingerprint, trustUnchanged=True, applicationBytesUnchanged=True,
                      cacheUnchangedAcrossFailures=True, plainHTTPRequests=0)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Native network acceptance passed: {evidence}', flush=True)
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()


def make_evidence_directory():
    root = FIXTURES / 'evidence/native-network'
    root.mkdir(parents=True, exist_ok=True)
    return root


if __name__ == '__main__':
    main()
