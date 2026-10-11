#!/usr/bin/env python3
"""Check real signed client/tool preflight and unavailable XPC, without root installation or GUI."""
import argparse
import hashlib
import json
import os
import plistlib
import re
import shutil
import signal
import subprocess
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_sparkle_compatibility import sign

ROOT, REPO = fixtures.ROOT, fixtures.REPO
TEST = 'realBrokerBoundaryWithoutGUIAutomation'
CASES = ['valid', 'mas', 'verifier', 'pin', 'wrong-id', 'adhoc', 'symlink', 'unavailable', 'cancelled']


def identity():
    signer = fixtures.manifest()['fixtures'][0]['signer']
    lines = fixtures.run(['security', 'find-identity', '-v', '-p', 'codesigning'], capture=True).splitlines()
    matches = [re.search(r'\b([A-F0-9]{40})\b', line).group(1) for line in lines if signer in line and re.search(r'\b([A-F0-9]{40})\b', line)]
    if len(matches) != 1: raise ValueError('Exactly one existing approved fixture signing identity is required.')
    return matches[0]


def prepare():
    manifest = fixtures.manifest()
    fixtures.run(['python3', 'scripts/package_app.py', '--identity', identity(), '--team', manifest['fixtures'][0]['team'],
                  '--public-key', manifest['publicKey']], cwd=REPO)
    destination = ROOT / 'evidence/headless-broker-boundary/baseline/Latest.app'
    if destination.exists(): shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(REPO / '.build/debug/Latest.app', destination, symlinks=True)
    fixtures.run(['codesign', '--verify', '--deep', '--strict', destination])
    return destination


def execute(case, app, evidence):
    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                 '--enable-swift-testing', '--disable-xctest', '--filter', TEST]
    environment = dict(fixtures.brew_environment(), LATEST_HEADLESS_BROKER_BOUNDARY=case, LATEST_HEADLESS_BROKER_APP=str(app))
    path = evidence / 'test.log'
    with path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            process.wait(timeout=240)
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
        print(text[-9000:]); raise ValueError('Required native broker boundary did not pass; skips are not proof.')
    return dict(arguments=arguments, pid=process.pid, log=str(path))


def run_case(case, baseline):
    evidence = ROOT / 'evidence/headless-broker-boundary' / case
    evidence.mkdir(parents=True, exist_ok=True)
    app = evidence / 'Latest.app'
    if app.exists(): shutil.rmtree(app)
    shutil.copytree(baseline, app, symlinks=True)
    controls = [baseline, ROOT / 'applications/Latest Sparkle Fixture.app', ROOT / 'applications/Secondary/Latest Sparkle Fixture.app',
                ROOT / 'applications/Latest Homebrew Fixture.app', ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    before = [digest_app(path) for path in controls]
    service = subprocess.run(['launchctl', 'print', 'system/io.github.mpwg.Latest.Broker'], capture_output=True, text=True)
    if case == 'unavailable' and (service.returncode == 0 or 'Could not find service' not in service.stderr):
        raise ValueError('Unavailable-service acceptance requires authoritative absence of the own privileged service.')
    resources = app / 'Contents/Resources'
    if case in ['mas', 'verifier']:
        binary = resources / ('mas' if case == 'mas' else 'LatestPackageVerifier')
        with binary.open('r+b') as file:
            file.seek(-1, 2); byte = file.read(1); file.seek(-1, 2); file.write(bytes([byte[0] ^ 1]))
    elif case == 'pin':
        path = app / 'Contents/Info.plist'; value = plistlib.loads(path.read_bytes())
        value['LatestMasSHA256'] = '0' * 64; path.write_bytes(plistlib.dumps(value)); sign(app)
    elif case == 'wrong-id':
        fixtures.run(['codesign', '--force', '--sign', identity(), '--identifier', 'io.github.mpwg.Latest.NativeForeign',
                      '--options', 'runtime', '--timestamp=none', app])
    elif case == 'adhoc':
        fixtures.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', app])
    elif case == 'symlink':
        (resources / 'mas').unlink(); (resources / 'mas').symlink_to(baseline / 'Contents/Resources/mas'); sign(app)
    mutation = digest_app(app)
    outcome = execute(case, app, evidence)
    if digest_app(app) != mutation or any(digest_app(path) != old for path, old in zip(controls, before)):
        raise ValueError('A read-only broker boundary changed the test bundle or an unrelated control.')
    sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts', 'LatestBroker']
               for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
    sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'scripts/package_app.py', Path(__file__)]
    info = plistlib.loads((baseline / 'Contents/Info.plist').read_bytes())
    result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                  environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                   xcode=fixtures.run(['xcodebuild', '-version'], capture=True), uid=os.getuid()),
                  signedBaselineRevision=info['LatestSourceRevision'], signingTeam=info['LatestSigningTeam'],
                  controlledApp=str(app), execution=outcome, GUIAutomation=False, controlsUnchanged=True,
                  noServiceRegistration=True, noRootToolExecution=True,
                  serviceObservation=dict(exitCode=service.returncode, stderr=service.stderr.strip()),
                  scope='Actual native static signatures, sealed tool preflight, pre-cancellation and absent-service client errors; privileged service acceptance remains open.')
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Headless native broker boundary {case}: passed; controlled signature/tool/client outcome, unchanged controls.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=CASES + ['all'])
    args = parser.parse_args()
    baseline = prepare()
    for case in CASES if args.case == 'all' else [args.case]: run_case(case, baseline)
