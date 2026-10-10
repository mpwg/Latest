#!/usr/bin/env python3
"""Run native provenance, stale-instance, catalogue and real failure/retry checks."""
import argparse
import hashlib
import json
import plistlib
import shutil
import subprocess
import uuid
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app, run_native_test

ROOT = fixtures.ROOT
CASES = {
    'loss': 'testNativeHomebrewProvenanceLoss',
    'swap': 'testNativeHomebrewChangedInstance',
    'catalogue': 'testNativeCatalogueCannotInstallUnmanagedNameMatch',
    'retry': 'testNativeHomebrewFailureThenRetry',
}


def run_case(name):
    environment = fixtures.brew_environment()
    brew = ROOT / 'homebrew/bin/brew'
    fixture = ROOT / 'applications/Latest Homebrew Fixture.app'
    fixtures.set_cask_version('1.0.0')
    result = subprocess.run([str(brew), 'list', '--cask'], check=True, capture_output=True, text=True, env=environment)
    verb = 'reinstall' if fixtures.TOKEN in result.stdout.splitlines() else 'install'
    if verb == 'install' and fixture.exists():
        info = plistlib.loads((fixture / 'Contents/Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != 'io.github.mpwg.Latest.NativeFixture.Homebrew':
            raise ValueError('Refusing to replace an unexpected app at the disposable fixture path.')
        backups = ROOT / 'evidence/l04/reset-backups'
        backups.mkdir(parents=True, exist_ok=True)
        shutil.move(fixture, backups / f'{uuid.uuid4().hex}.app')
    fixtures.run([brew, verb, '--cask', '--no-ask', f'--appdir={ROOT / "applications"}', f'{fixtures.TAP}/{fixtures.TOKEN}'], env=environment)
    fixtures.set_cask_version('1.1.0')
    sibling = ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app'
    sibling.parent.mkdir(exist_ok=True)
    if not sibling.exists():
        shutil.copytree(ROOT / 'versions/homebrew/1.0.0/Latest Homebrew Fixture.app', sibling)
    controls = {sibling: digest_app(sibling), ROOT / 'applications/Latest Sparkle Fixture.app': digest_app(ROOT / 'applications/Latest Sparkle Fixture.app')}
    host_casks = fixtures.run(['brew', 'list', '--cask'], capture=True)
    cask = ROOT / 'homebrew/Library/Taps/mpwg/homebrew-latest-native-fixtures/Casks' / f'{fixtures.TOKEN}.rb'
    if name == 'retry':
        text = cask.read_text()
        valid = hashlib.sha256((ROOT / 'web/LatestHomebrewFixture-1.1.0.zip').read_bytes()).hexdigest()
        cask.write_text(text.replace(valid, '0' * 64))
    if name == 'catalogue':
        (ROOT / 'web/catalogue.json').write_text(json.dumps({'casks': [{'token': 'informational-fixture', 'version': '2.0.0', 'artifacts': [{'app': ['Latest Homebrew Fixture.app']}]}]}))
    state = ROOT / 'preferences/l03'
    state.mkdir(parents=True, exist_ok=True)
    (state / 'preferences.json').write_text(json.dumps({'directories': [{'path': str(ROOT / 'applications'), 'enabled': True}], 'showCatalogueHints': name == 'catalogue'}))
    evidence = ROOT / 'evidence/l04'
    evidence.mkdir(parents=True, exist_ok=True)
    stages = {'loss': 'LOSS', 'swap': 'SWAP', 'retry': 'RETRY'}
    stage = stages.get(name)
    ready = evidence / f'{stage}-ready'
    if stage and ready.exists():
        ready.unlink()
    changed = False
    failure_version = None

    def coordinate(log):
        nonlocal changed, failure_version
        if changed or not stage or f'L04_READY_{stage}' not in log:
            return
        if name == 'loss':
            fixtures.run([brew, 'uninstall', '--cask', fixtures.TOKEN], env=environment)
            shutil.copytree(ROOT / 'versions/homebrew/1.0.0/Latest Homebrew Fixture.app', fixture)
        elif name == 'swap':
            backup = evidence / f'selected-before-swap-{uuid.uuid4().hex}.app'
            shutil.move(fixture, backup)
            shutil.copytree(ROOT / 'versions/homebrew/1.1.0/Latest Homebrew Fixture.app', fixture)
        elif name == 'retry':
            failure_version = plistlib.loads((fixture / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
            if failure_version != '1.0.0':
                raise ValueError('A failed checksum update changed the installed version.')
            fixtures.set_cask_version('1.1.0')
        ready.write_text('External controlled fixture change completed.\n')
        changed = True

    outcome = run_native_test(CASES[name], evidence / name, coordinate)
    if stage and not changed:
        raise ValueError('The required external fixture change did not execute.')
    if name != 'retry' and outcome['observedUpgradeProcesses']:
        raise ValueError('A rejected/informational request started an upgrade.')
    if name == 'retry' and len(outcome['upgradeProcessIDs']) < 2:
        raise ValueError('The actual failed update and successful retry were not both observed.')
    for app, before in controls.items():
        if digest_app(app) != before:
            raise ValueError('An unrelated control app changed.')
    if fixtures.run(['brew', 'list', '--cask'], capture=True) != host_casks:
        raise ValueError('The host cask registry changed.')
    after = plistlib.loads((fixture / 'Contents/Info.plist').read_bytes())
    result = dict(case=name, nativeTest=CASES[name], sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  sourceHashes={str(path.relative_to(fixtures.REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                for path in [fixtures.REPO/'Sources/LatestApp/AppModel.swift', fixtures.REPO/'Sources/LatestPlatform/Catalogue.swift',
                                             fixtures.REPO/'Sources/LatestProcess/CommandRunner.swift', fixtures.REPO/'Tests/LatestUITests/LatestUITests.swift']},
                  finalVersion=after['CFBundleShortVersionString'], failedAttemptVersion=failure_version,
                  unrelatedFixturesUnchanged=True, hostCasksUnchanged=True, **outcome)
    (evidence / name / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'L04 {name}: native UI check passed; real upgrade processes: {len(outcome["upgradeProcessIDs"])}.', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=[*CASES, 'all'], default='all', nargs='?')
    arguments = parser.parse_args()
    for case in CASES if arguments.case == 'all' else [arguments.case]:
        run_case(case)
