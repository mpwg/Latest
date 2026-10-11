#!/usr/bin/env python3
"""Exercise the real isolated brew through the shared core, with no GUI automation."""
import argparse
import hashlib
import json
import plistlib
import shutil
import signal
import subprocess
import time
import uuid
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app

ROOT = fixtures.ROOT
REPO = fixtures.REPO
TEST = 'realHomebrewRuntimeWithoutGUIAutomation'


def baseline(environment, selected, brew):
    fixtures.set_cask_version('1.0.0')
    installed = fixtures.run([brew, 'list', '--cask'], capture=True, env=environment).splitlines()
    if any(token != fixtures.TOKEN for token in installed):
        raise ValueError('The isolated prefix contains an unexpected cask.')
    if selected.exists():
        info = plistlib.loads((selected / 'Contents/Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != 'io.github.mpwg.Latest.NativeFixture.Homebrew':
            raise ValueError('Unexpected app at the disposable managed path.')
    if fixtures.TOKEN not in installed and selected.exists():
        saved = ROOT / 'evidence/headless-homebrew/reset-backups'
        saved.mkdir(parents=True, exist_ok=True)
        shutil.move(selected, saved / (uuid.uuid4().hex + '.app'))
    fixtures.run([brew, 'reinstall' if fixtures.TOKEN in installed else 'install', '--cask', '--no-ask',
                  f'--appdir={ROOT / "applications"}', f'{fixtures.TAP}/{fixtures.TOKEN}'], env=environment)
    fixtures.set_cask_version('1.1.0')


def execute(arguments, environment, log_path, coordinate=None):
    observed = {}
    with log_path.open('w') as log:
        process = subprocess.Popen(arguments, cwd=REPO, env=environment, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 180
        try:
            while process.poll() is None:
                if time.monotonic() >= deadline:
                    raise TimeoutError('The controlled headless native process exceeded its deadline.')
                if coordinate: coordinate()
                listing = subprocess.check_output(['ps', '-axww', '-o', 'pid=,command='], text=True)
                for line in listing.splitlines():
                    parts = line.strip().split(None, 1)
                    if len(parts) == 2 and str(ROOT / 'homebrew') in parts[1] and f'upgrade --cask --no-ask {fixtures.TOKEN}' in parts[1]:
                        observed[parts[0]] = parts[1]
                time.sleep(0.05)
        finally:
            if process.poll() is None:
                os_group = process.pid
                try: __import__('os').killpg(os_group, signal.SIGTERM)
                except ProcessLookupError: pass
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    try: __import__('os').killpg(os_group, signal.SIGKILL)
                    except ProcessLookupError: pass
                    process.wait()
    text = log_path.read_text()
    if process.returncode or f'{TEST}() passed' not in text:
        print(text[-8000:]); raise ValueError('Required real native core test did not pass; skips are not evidence.')
    return observed


def run_case(case):
    manifest = fixtures.manifest()
    if Path(manifest['brewPrefix']) != ROOT / 'homebrew' or (ROOT / 'homebrew').is_symlink():
        raise ValueError('Only the prepared isolated prefix may be updated.')
    if (ROOT / 'homebrew/Library/Homebrew/vendor/portable-ruby').is_symlink():
        raise ValueError('The isolated vendor directory must not point into the host runtime.')
    environment = fixtures.brew_environment()
    brew = ROOT / 'homebrew/bin/brew'
    selected = ROOT / 'applications/Latest Homebrew Fixture.app'
    baseline(environment, selected, brew)
    sibling = ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app'
    if not sibling.exists():
        sibling.parent.mkdir(exist_ok=True)
        shutil.copytree(ROOT / 'versions/homebrew/1.0.0/Latest Homebrew Fixture.app', sibling)
    controls = [sibling, ROOT / 'applications/Latest Sparkle Fixture.app', ROOT / 'applications/Secondary/Latest Sparkle Fixture.app']
    before_controls = {str(app): digest_app(app) for app in controls}
    before = digest_app(selected)
    host_environment = dict(environment, XDG_CONFIG_HOME=str(ROOT / 'host-read-only-config'))
    host_before = fixtures.run(['brew', 'list', '--cask'], capture=True, env=host_environment)
    host_vendor = Path('/opt/homebrew/Library/Homebrew/vendor/portable-ruby')
    vendor_before = digest_app(host_vendor)
    state = ROOT / 'preferences/headless-homebrew'
    state.mkdir(parents=True, exist_ok=True)
    journal = state / 'job-events.jsonl'; journal.write_text('')
    evidence = ROOT / 'evidence/headless-homebrew' / case
    evidence.mkdir(parents=True, exist_ok=True)
    coordination = ROOT / 'evidence/headless-homebrew/coordination'
    coordination.mkdir(parents=True, exist_ok=True)
    for phase in ['loss', 'swap', 'retry']:
        for suffix in ['ready', 'released']:
            path = coordination / f'{phase}-{suffix}'
            if path.exists(): path.unlink()
    cask = ROOT / 'homebrew/Library/Taps/mpwg/homebrew-latest-native-fixtures/Casks' / f'{fixtures.TOKEN}.rb'
    valid_cask = cask.read_bytes()
    catalogue = ROOT / 'web/catalogue-headless.json'
    old_catalogue = catalogue.read_bytes() if catalogue.exists() else None
    if case == 'retry':
        checksum = hashlib.sha256((ROOT / 'web/LatestHomebrewFixture-1.1.0.zip').read_bytes()).hexdigest()
        cask.write_text(cask.read_text().replace(checksum, '0' * 64))
    if case == 'catalogue':
        catalogue.write_text(json.dumps({'casks': [{'token': 'informational-fixture', 'version': '2.0.0',
                                                  'artifacts': [{'app': ['Latest Homebrew Fixture.app']}]}]}))
        environment['LATEST_HEADLESS_NATIVE_CATALOGUE'] = f'https://localhost:{manifest["port"]}/catalogue-headless.json'
    environment['LATEST_HEADLESS_NATIVE_HOMEBREW'] = case
    checkpoints = {}
    after_external = None

    def coordinate():
        nonlocal after_external
        ready = coordination / f'{case}-ready'
        released = coordination / f'{case}-released'
        if not ready.exists() or released.exists(): return
        if case == 'loss':
            # Preserve the very same bundle/inodes while brew removes genuine registration.
            parked = evidence / ('parked-' + uuid.uuid4().hex + '.app')
            shutil.move(selected, parked)
            try: fixtures.run([brew, 'uninstall', '--cask', fixtures.TOKEN], env=environment)
            finally: shutil.move(parked, selected)
            checkpoints['selectedBytesUnchangedAtOwnershipLoss'] = digest_app(selected) == before
            if not checkpoints['selectedBytesUnchangedAtOwnershipLoss']:
                raise ValueError('Ownership-loss setup changed the selected bundle.')
        elif case == 'swap':
            parked = evidence / ('selected-before-swap-' + uuid.uuid4().hex + '.app')
            shutil.move(selected, parked)
            shutil.copytree(ROOT / 'versions/homebrew/1.1.0/Latest Homebrew Fixture.app', selected)
            after_external = digest_app(selected)
        elif case == 'retry':
            if digest_app(selected) != before: raise ValueError('The failed real checksum update changed the selected app.')
            checkpoints['failedAttemptSelectedUnchanged'] = True
            checkpoints['failedAttemptEvents'] = [json.loads(line) for line in journal.read_text().splitlines()]
            cask.write_bytes(valid_cask)
        checkpoints['externalOperationCompleted'] = True
        released.write_text('Actual external fixture operation completed.\n')

    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build', '--enable-swift-testing',
                 '--disable-xctest', '--filter', TEST]
    try:
        observed = execute(arguments, environment, evidence / 'test.log', coordinate)
        expected_version = '1.1.0' if case in ['valid', 'swap', 'retry'] else '1.0.0'
        expected_status = 'current' if case in ['valid', 'retry'] else 'unknown' if case in ['loss', 'catalogue'] else 'available'
        if case == 'catalogue': expected_version = plistlib.loads((sibling / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString']
        restart_environment = dict(environment, LATEST_HEADLESS_NATIVE_HOMEBREW='checked',
                                   LATEST_HEADLESS_NATIVE_EXPECTED_VERSION=expected_version,
                                   LATEST_HEADLESS_NATIVE_EXPECTED_STATUS=expected_status)
        if case == 'catalogue': restart_environment['LATEST_HEADLESS_NATIVE_HOMEBREW_TARGET'] = 'unmanaged'
        restart_observed = execute(arguments, restart_environment, evidence / 'restart.log')
        if restart_observed: raise ValueError('A read-only restart unexpectedly invoked upgrade.')
        required_processes = 2 if case == 'retry' else 1 if case == 'valid' else 0
        if len(observed) < required_processes or (required_processes == 0 and observed):
            raise ValueError('The actual targeted upgrade process evidence does not match this case.')
        if case in ['loss', 'catalogue'] and digest_app(selected) != before:
            raise ValueError('A rejected/informational request changed the selected bundle.')
        if case == 'swap' and digest_app(selected) != after_external:
            raise ValueError('The rejected stale request changed the replaced bundle.')
        for app in controls:
            if digest_app(app) != before_controls[str(app)]: raise ValueError('An unrelated app instance changed.')
        if fixtures.run(['brew', 'list', '--cask'], capture=True, env=host_environment) != host_before:
            raise ValueError('The host cask registry changed.')
        if digest_app(host_vendor) != vendor_before: raise ValueError('The host Ruby runtime changed.')
        target = sibling if case == 'catalogue' else selected
        fixtures.run(['codesign', '--verify', '--deep', '--strict', target])
        architectures = fixtures.run(['lipo', '-archs', target / 'Contents/MacOS/FixtureApp'], capture=True)
        if architectures != 'arm64': raise ValueError('Unexpected actual fixture architecture.')
        events = [json.loads(line) for line in journal.read_text().splitlines()]
        if any(event['path'] != str(selected) for event in events): raise ValueError('A job targeted another instance.')
        jobs = {}
        for event in events: jobs.setdefault(event['job'], []).append(event['phase'])
        terminals = [[phase for phase in phases if phase in ['succeeded', 'failed', 'cancelled']] for phases in jobs.values()]
        expected_terminals = [] if case == 'catalogue' else [['failed'], ['succeeded']] if case == 'retry' else [['succeeded']] if case == 'valid' else [['failed']]
        if terminals != expected_terminals: raise ValueError('Exactly one required terminal outcome per actual job was not observed.')
        if case in ['loss', 'swap', 'retry'] and not checkpoints: raise ValueError('Native checkpoint was not executed.')
        sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
                   for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
        sources += [REPO / 'Tests/LatestCoreTests/CoreTests.swift', REPO / 'scripts/native_fixtures.py', Path(__file__)]
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      environment={name: fixtures.run(command, capture=True) for name, command in
                                   [('macOS', ['sw_vers', '-productVersion']), ('Xcode', ['xcodebuild', '-version']),
                                    ('Swift', ['swift', '--version']), ('architecture', ['uname', '-m'])]},
                      selectedPath=str(target), expectedVersion=expected_version, expectedStatus=expected_status,
                      observedUpgradeProcesses=observed, jobPhases=list(jobs.values()), checkpoints=checkpoints,
                      newProcessRestartVerified=True, unrelatedInstancesUnchanged=True, hostCasksUnchanged=True,
                      hostRubyUnchanged=True, signatureVerified=True, actualArchitecture=architectures, GUIAutomation=False)
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Headless native Homebrew {case}: passed; real upgrade processes {len(observed)}, exact terminal outcomes {terminals}.')
    finally:
        cask.write_bytes(valid_cask)
        if old_catalogue is None:
            if catalogue.exists(): catalogue.unlink()
        else: catalogue.write_bytes(old_catalogue)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['valid', 'loss', 'swap', 'catalogue', 'retry', 'all'])
    args = parser.parse_args()
    for case in (['valid', 'loss', 'swap', 'catalogue', 'retry'] if args.case == 'all' else [args.case]): run_case(case)
