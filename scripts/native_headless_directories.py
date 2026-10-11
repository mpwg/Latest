#!/usr/bin/env python3
"""Check real directory persistence, volume recovery and scan supersession without GUI automation."""
import argparse
import hashlib
import json
import os
import signal
import subprocess
import time
from pathlib import Path
import native_fixtures as fixtures
from native_directories import run_case as prepare_and_verify
from native_homebrew_acceptance import digest_app

ROOT, REPO = fixtures.ROOT, fixtures.REPO
TEST = 'realDirectoriesWithoutGUIAutomation'
CASES = ['actions', 'volume', 'empty-volume', 'stale']


def execute(case, evidence, coordinate=None, restart=False):
    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                 '--enable-swift-testing', '--disable-xctest', '--filter', TEST]
    environment = dict(fixtures.brew_environment(), LATEST_HEADLESS_DIRECTORIES=case)
    if restart: environment['LATEST_HEADLESS_DIRECTORIES_RESTART'] = '1'
    path = evidence / ('restart.log' if restart else 'test.log')
    with path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 240
        try:
            while process.poll() is None:
                if time.monotonic() >= deadline: raise TimeoutError('The real directory/volume test exceeded its deadline.')
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
        print(text[-9000:]); raise ValueError('The required native directory/volume test did not pass; skips are not proof.')
    return dict(arguments=arguments, pid=process.pid, log=str(path))


def run_case(case):
    fixtures.manifest()
    fixtures.run(['security', 'verify-cert', '-c', ROOT / 'tls.crt', '-p', 'ssl', '-n', 'localhost', '-L'], capture=True)
    vendor = Path('/opt/homebrew/Library/Homebrew/vendor/portable-ruby')
    before = digest_app(vendor) if vendor.is_dir() else {}

    def runner(_historical_test, evidence, coordinate):
        initial = execute(case, evidence, coordinate)
        restart = execute(case, evidence, coordinate, restart=True)
        return dict(testIdentifier='NativeDirectoryTests/' + TEST, execution=initial, restart=restart,
                    GUIAutomation=False, directProductionSession=True, newProcessRestartVerified=True)

    result = prepare_and_verify(case, test_runner=runner, evidence_directory='headless-directories',
                                state_directory='headless-directories')
    if before and digest_app(vendor) != before: raise ValueError('Ordinary Homebrew Ruby runtime changed.')
    volume = result['paths'].get('volume')
    if volume and Path(volume).exists(): raise ValueError('Owned disposable volume was not detached after verification.')
    sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
               for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
    sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'Tests/NativeFixtures/FixtureApp.swift',
                REPO / 'scripts/native_fixtures.py', REPO / 'scripts/native_directories.py',
                REPO / 'scripts/native_major_bulk.py', REPO / 'scripts/native_sparkle_compatibility.py', Path(__file__)]
    result['sourceSHA256'] = {str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    result['ordinaryHomebrewRuntimeUnchanged'] = True
    result['ownedVolumeDetachedAfterAcceptance'] = True
    path = ROOT / 'evidence/headless-directories' / case / 'result.json'
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(f'Headless native directories {case}: passed; actual mounts/checkpoints, new process and unchanged bundles.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=CASES + ['all'])
    args = parser.parse_args()
    for case in CASES if args.case == 'all' else [args.case]: run_case(case)
