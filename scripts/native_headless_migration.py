#!/usr/bin/env python3
"""Verify actual CFPreferences/JSON migration through the shared reader and session."""
import argparse
import hashlib
import json
import os
import plistlib
import shutil
import signal
import subprocess
import uuid
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import digest_app
from native_migration import legacy_fingerprint, file_digest

ROOT, REPO = fixtures.ROOT, fixtures.REPO
TEST = 'realLegacyMigrationWithoutGUIAutomation'


def execute(phase, domain, profile, evidence):
    arguments = ['swift', 'test', '--build-system', 'native', '--skip-build',
                 '--enable-swift-testing', '--disable-xctest', '--filter', TEST]
    environment = dict(fixtures.brew_environment(), LATEST_HEADLESS_MIGRATION_PHASE=phase,
                       LATEST_HEADLESS_MIGRATION_DOMAIN=domain, LATEST_HEADLESS_MIGRATION_PROFILE=str(profile))
    path = evidence / (phase + '.log')
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
        print(text[-9000:]); raise ValueError('Actual migration phase did not pass; skips are not proof.')
    return dict(phase=phase, arguments=arguments, pid=process.pid, log=str(path))


def run_case(case):
    fixtures.manifest()
    evidence = ROOT / 'evidence/headless-migration' / case / uuid.uuid4().hex
    evidence.mkdir(parents=True)
    profile = evidence / 'profile'; profile.mkdir()
    domain = 'io.github.mpwg.Latest.NativeMigration.Headless.' + evidence.name
    migrated = profile / 'Ältere Apps'; migrated.mkdir()
    controlled_app = migrated / 'Latest Migration Fixture.app'
    shutil.copytree(ROOT / 'versions/sparkle/1.0.0/Latest Sparkle Fixture.app', controlled_app)
    controls = [controlled_app, ROOT / 'applications/Latest Sparkle Fixture.app',
                ROOT / 'applications/Secondary/Latest Sparkle Fixture.app', ROOT / 'applications/Latest Homebrew Fixture.app',
                ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app']
    before = [digest_app(app) for app in controls]
    ordinary = dict(legacySHA256=legacy_fingerprint(), preferencesSHA256=file_digest(Path.home() / 'Library/Application Support/io.github.mpwg.Latest/preferences.json'))
    legacy = (dict(directoryPaths=[str(migrated), str(migrated), 'relative'],
                   IgnoredAppsKey=['io.github.mpwg.Latest.LegacyIgnored'], ShowInstalledUpdatesKey=False,
                   ShowIgnoredUpdatesKey=True, ShowUnsupportedUpdatesKey=False) if case == 'valid' else
              dict(directoryPaths=['relative'], IgnoredAppsKey='invalid-array',
                   ShowInstalledUpdatesKey='invalid-boolean', ShowUnsupportedUpdatesKey='invalid-boolean'))
    source = evidence / 'legacy.plist'; source.write_bytes(plistlib.dumps(legacy))
    checkpoints = []
    preferences = profile / 'Library/Application Support/io.github.mpwg.Latest/preferences.json'
    try:
        fixtures.run(['defaults', 'import', domain, source], capture=True)
        phases = ['migrated', 'edited', 'restarted'] if case == 'valid' else ['malformed', 'malformed-restart']
        for phase in phases:
            if phase == 'restarted':
                changed = evidence / 'changed-legacy.plist'
                changed.write_bytes(plistlib.dumps(dict(directoryPaths=[str(profile / 'Should Not Migrate')],
                    IgnoredAppsKey=['io.github.mpwg.Latest.ShouldNotReplace'], ShowInstalledUpdatesKey=False,
                    ShowIgnoredUpdatesKey=True, ShowUnsupportedUpdatesKey=False)))
                fixtures.run(['defaults', 'import', domain, changed], capture=True)
            checkpoint = execute(phase, domain, profile, evidence)
            value = json.loads(preferences.read_text())
            expected_visibility = [False, True, False] if phase == 'migrated' else [True, False, True]
            if [value['showCurrent'], value['showIgnored'], value['showUnknown']] != expected_visibility:
                raise ValueError('Actual persisted visibility differs from the expected migration/default/edit result.')
            paths = [item['path'] for item in value['directories']]
            if 'relative' in paths or str(profile / 'Should Not Migrate') in paths: raise ValueError('Unsafe or repeated migration directory.')
            if case == 'valid':
                if paths.count(str(migrated)) != 1 or value['ignoredBundleIDs'] != legacy['IgnoredAppsKey']:
                    raise ValueError('Migrated unique directories or ignored IDs did not persist.')
                if phase in ['edited', 'restarted'] and (not value['sortBySource'] or value['fontScale'] != 1.4):
                    raise ValueError('Edited settings were overwritten or not persisted.')
            elif value['ignoredBundleIDs']: raise ValueError('Malformed ignore field was accepted.')
            checkpoint['persistedPreferences'] = value; checkpoints.append(checkpoint)
        journal = preferences.parent / 'job-events.jsonl'
        if journal.exists() and journal.read_text().strip(): raise ValueError('Migration started an installation job.')
        if any(digest_app(app) != old for app, old in zip(controls, before)): raise ValueError('A controlled app changed.')
        after = dict(legacySHA256=legacy_fingerprint(), preferencesSHA256=file_digest(Path.home() / 'Library/Application Support/io.github.mpwg.Latest/preferences.json'))
        if after != ordinary: raise ValueError('Ordinary preference domain/file changed; no restoration is attempted.')
        fixtures.run(['codesign', '--verify', '--deep', '--strict', controlled_app])
        architecture = fixtures.run(['lipo', '-archs', controlled_app / 'Contents/MacOS/FixtureApp'], capture=True)
        if architecture != 'arm64': raise ValueError('Controlled migration fixture architecture changed.')
        sources = [path for layer in ['LatestCore', 'LatestApplication', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']
                   for path in sorted((REPO / 'Sources' / layer).glob('*.swift'))]
        sources += [REPO / 'Sources/LatestApp/AppModel.swift', REPO / 'Tests/LatestCoreTests/CoreTests.swift',
                    REPO / 'scripts/native_migration.py', Path(__file__)]
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      environment=dict(macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True),
                                       xcode=fixtures.run(['xcodebuild', '-version'], capture=True), architecture=architecture),
                      profile=str(profile), legacyDomain=domain, checkpoints=checkpoints,
                      ordinaryBefore=ordinary, ordinaryAfter=after, ordinaryUserPreferencesUnchanged=True,
                      allControlledBundlesUnchanged=True, noInstallationJobs=True, GUIAutomation=False,
                      realCFPreferences=True, newProcessRestartVerified=True,
                      inventoryScope='Actual native discovery restricted to this private profile; no real provider/network checks or installations.')
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Headless actual migration {case}: passed; native CFPreferences, real JSON and fresh processes. Evidence: {evidence}', flush=True)
    finally:
        subprocess.run(['defaults', 'delete', domain], capture_output=True, check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['valid', 'malformed', 'all'])
    args = parser.parse_args()
    for case in ['valid', 'malformed'] if args.case == 'all' else [args.case]: run_case(case)
