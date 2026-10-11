#!/usr/bin/env python3
"""Drive signed major consent and scoped bulk installation through the shared core."""
import argparse
import hashlib
import json
import os
import signal
import ssl
import subprocess
import time
import urllib.request
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_major_bulk import run_case as prepare_and_verify

ROOT, REPO = fixtures.ROOT, fixtures.REPO
TEST = 'realMajorBulkWithoutGUIAutomation'
CASES = ['major', 'provider-major', 'changed-major', 'bulk']


def execute(case, evidence, coordinate=None, restart=False):
    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                 '--enable-swift-testing', '--disable-xctest', '--filter', TEST]
    environment = dict(fixtures.brew_environment(), LATEST_HEADLESS_MAJOR_BULK=case)
    if restart: environment['LATEST_HEADLESS_MAJOR_BULK_RESTART'] = '1'
    path = evidence / ('restart.log' if restart else 'test.log')
    with path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 240
        try:
            while process.poll() is None:
                if time.monotonic() >= deadline: raise TimeoutError('The real major/bulk test exceeded its deadline.')
                if coordinate: coordinate(path.read_text())
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
    text = path.read_text()
    if process.returncode or f'{TEST}() passed' not in text:
        print(text[-9000:]); raise ValueError('The required native major/bulk test did not pass; skips are not proof.')
    return dict(arguments=arguments, pid=process.pid, log=str(path))


def run_case(case):
    manifest = fixtures.manifest()
    fixtures.run(['security', 'verify-cert', '-c', ROOT / 'tls.crt', '-p', 'ssl', '-n', 'localhost', '-L'], capture=True)
    with urllib.request.urlopen(f"https://localhost:{manifest['port']}/appcast.xml",
                               context=ssl.create_default_context(cafile=ROOT / 'tls.crt'), timeout=5) as response:
        if response.status != 200: raise ValueError('Start the controlled HTTPS fixture server first.')
    vendor = Path('/opt/homebrew/Library/Homebrew/vendor/portable-ruby')
    before = digest_app(vendor) if vendor.is_dir() else {}

    def runner(_historical_test, evidence, coordinate):
        initial = execute(case, evidence, coordinate)
        restart = execute(case, evidence, restart=True)
        return dict(testIdentifier='NativeMajorBulkTests/' + TEST, execution=initial, restart=restart,
                    GUIAutomation=False, directProductionSession=True, newProcessRestartVerified=True)

    result = prepare_and_verify(case, test_runner=runner, evidence_directory='headless-major-bulk',
                                state_directory='headless-major-bulk')
    if before and digest_app(vendor) != before: raise ValueError('The ordinary Homebrew Ruby runtime changed.')
    downloads = {path: count for path, count in result['requestCounts'].items() if path.endswith('.zip')}
    expected = {} if case == 'changed-major' else {'/selected.zip': 1, **({'/minor.zip': 1} if case == 'bulk' else {})}
    if downloads != expected: raise ValueError('Unexpected, excluded or duplicate actual archive download.')
    sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
               for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
    sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'Tests/NativeFixtures/FixtureApp.swift',
                REPO / 'scripts/native_fixtures.py', REPO / 'scripts/native_major_bulk.py',
                REPO / 'scripts/native_sparkle_compatibility.py', Path(__file__)]
    result['sourceSHA256'] = {str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    result['ordinaryHomebrewRuntimeUnchanged'] = True
    result['exactArchiveDownloadsVerified'] = True
    path = ROOT / 'evidence/headless-major-bulk' / case / 'result.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Headless native {case}: passed; exact downloads, terminal jobs, restart and unchanged excluded apps.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=CASES + ['all'])
    args = parser.parse_args()
    for case in CASES if args.case == 'all' else [args.case]: run_case(case)
