#!/usr/bin/env python3
"""Update the disposable real cask via native XCUITest and verify other fixtures."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import time
import uuid
import native_fixtures

REPO = native_fixtures.REPO
ROOT = native_fixtures.ROOT


def digest_app(app):
    return {str(path.relative_to(app)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(app.rglob('*')) if path.is_file() and not path.is_symlink()}


def run_native_test(test_name, evidence, coordinate=None):
    manifest = native_fixtures.manifest()
    environment = native_fixtures.brew_environment()
    environment.update(LATEST_NATIVE_FIXTURE_ROOT=str(ROOT), TEST_RUNNER_LATEST_NATIVE_FIXTURE_ROOT=str(ROOT))
    identities = native_fixtures.run(['security', 'find-identity', '-v', '-p', 'codesigning'], capture=True)
    signer = manifest['fixtures'][0]['signer']
    matching = [re.search(r'\b([A-F0-9]{40})\b', line).group(1) for line in identities.splitlines()
                if signer in line and re.search(r'\b([A-F0-9]{40})\b', line)]
    if len(matching) != 1:
        raise ValueError('Exactly one available own signing identity must match the prepared fixtures.')
    evidence.mkdir(parents=True, exist_ok=True)
    result_bundle = evidence / f'native-tests-{uuid.uuid4().hex}.xcresult'
    arguments = ['xcodebuild', '-project', str(REPO / 'Latest.xcodeproj'), '-scheme', 'Latest',
                 '-destination', 'platform=macOS', '-derivedDataPath', str(REPO / '.build/l03-xcode'),
                 '-resultBundlePath', str(result_bundle), f'-only-testing:LatestUITests/LatestUITests/{test_name}',
                 'CODE_SIGN_STYLE=Manual', 'CODE_SIGN_IDENTITY=' + matching[0],
                 'DEVELOPMENT_TEAM=' + manifest['fixtures'][0]['team'], 'test']
    observed = {}
    log_path = evidence / 'native-tests.log'
    with log_path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT)
        while process.poll() is None:
            if coordinate:
                coordinate(log_path.read_text(errors='replace'))
            commands = subprocess.run(['ps', '-axww', '-o', 'pid=,command='], check=True, capture_output=True, text=True).stdout.splitlines()
            for line in commands:
                pid, command = line.strip().split(None, 1)
                if str(ROOT / 'homebrew') in command and f'upgrade --cask --no-ask {native_fixtures.TOKEN}' in command:
                    observed.setdefault(pid, set()).add(command)
            time.sleep(0.1)
    if process.returncode:
        print(log_path.read_text()[-7000:])
        raise subprocess.CalledProcessError(process.returncode, arguments)
    if f"{test_name}]' passed" not in log_path.read_text():
        raise ValueError('The required native test did not execute successfully; skipped tests are not acceptance.')
    return dict(resultBundle=str(result_bundle), observedUpgradeProcesses=sorted({command for commands in observed.values() for command in commands}),
                upgradeProcessIDs=sorted(observed))


def main():
    manifest = native_fixtures.manifest()
    if not manifest['brewPrefix'] or Path(manifest['brewPrefix']) != ROOT / 'homebrew':
        raise ValueError('Prepare the isolated native fixture prefix first.')
    installed = ROOT / 'applications/Latest Homebrew Fixture.app'
    baseline = plistlib.loads((installed / 'Contents/Info.plist').read_bytes())
    if baseline['CFBundleShortVersionString'] != '1.0.0':
        raise ValueError('Reset the disposable cask to 1.0.0 before running positive acceptance.')
    sibling = ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app'
    sibling.parent.mkdir(exist_ok=True)
    if not sibling.exists():
        shutil.copytree(ROOT / 'versions/homebrew/1.0.0/Latest Homebrew Fixture.app', sibling)
    sibling_before = digest_app(sibling)
    sparkle = ROOT / 'applications/Latest Sparkle Fixture.app'
    sparkle_before = digest_app(sparkle)
    host_casks = native_fixtures.run(['brew', 'list', '--cask'], capture=True)
    environment = native_fixtures.brew_environment()
    (ROOT / 'user-config').mkdir(exist_ok=True)
    brew = ROOT / 'homebrew/bin/brew'
    native_fixtures.run([brew, 'trust', '--cask', f'{native_fixtures.TAP}/{native_fixtures.TOKEN}'], env=environment)
    native_fixtures.set_cask_version('1.1.0')
    state = ROOT / 'preferences/l03'
    state.mkdir(parents=True, exist_ok=True)
    (state / 'preferences.json').write_text(json.dumps({'directories': [{'path': str(ROOT / 'applications'), 'enabled': True}]}))
    evidence = ROOT / 'evidence/l03'
    evidence.mkdir(parents=True, exist_ok=True)
    outcome = run_native_test('testNativeHomebrewUpdate', evidence)
    if not outcome['observedUpgradeProcesses']:
        raise ValueError('No real targeted brew invocation was observed; check for skipped native tests.')
    after = plistlib.loads((installed / 'Contents/Info.plist').read_bytes())
    if after['CFBundleShortVersionString'] != '1.1.0' or after['CFBundleIdentifier'] != baseline['CFBundleIdentifier']:
        raise ValueError('The selected installed bundle does not match the expected update.')
    if sibling_before != digest_app(sibling) or sparkle_before != digest_app(sparkle):
        raise ValueError('An unrelated fixture app changed during the targeted update.')
    if host_casks != native_fixtures.run(['brew', 'list', '--cask'], capture=True):
        raise ValueError('The normal Homebrew cask registry changed.')
    result = dict(before='1.0.0 (1)', after='1.1.0 (2)', bundleID=after['CFBundleIdentifier'], path=str(installed),
                  sourceRevision=native_fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  applicationModelSHA256=hashlib.sha256((REPO / 'Sources/LatestApp/AppModel.swift').read_bytes()).hexdigest(),
                  testSourceSHA256=hashlib.sha256((REPO / 'Tests/LatestUITests/LatestUITests.swift').read_bytes()).hexdigest(),
                  nativeTest='LatestUITests/testNativeHomebrewUpdate', **outcome,
                  unrelatedFixturesUnchanged=True, hostCasksUnchanged=True,
                  upgradeArguments=['upgrade', '--cask', '--no-ask', native_fixtures.TOKEN])
    (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print('Native Homebrew XCUITest passed: actual UI update action, installed 1.1.0, post-verification current status and retained screenshots.')
    print('Result bundle:', outcome['resultBundle'])


if __name__ == '__main__':
    main()
