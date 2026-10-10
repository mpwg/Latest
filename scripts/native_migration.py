#!/usr/bin/env python3
"""Verify normal signed startup migration with isolated filesystem and CFPreferences data."""
import argparse
import hashlib
import json
import plistlib
import subprocess
import uuid
from pathlib import Path
import native_fixtures as fixtures
from native_homebrew_acceptance import run_native_test

REPO = fixtures.REPO
ROOT = fixtures.ROOT


def legacy_values():
    result = subprocess.run(['defaults', 'export', 'com.max-langer.Latest', '-'], capture_output=True)
    if result.returncode:
        return None
    return plistlib.loads(result.stdout)


def legacy_fingerprint():
    values = legacy_values()
    return hashlib.sha256(plistlib.dumps(values, sort_keys=True)).hexdigest() if values is not None else None


def file_digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def restore_legacy_check_time(before, snapshot):
    after = legacy_values()
    changed = {key for key in set(before or {}) | set(after or {}) if (before or {}).get(key) != (after or {}).get(key)}
    if changed == {'SULastCheckTime'} and before is not None:
        # Normal discovery checks the installed legacy app; preserve its prior runtime metadata.
        subprocess.run(['defaults', 'import', 'com.max-langer.Latest', str(snapshot)], check=True, capture_output=True)
        return True
    if changed:
        raise ValueError('Unexpected ordinary legacy changes; refusing to overwrite unrelated settings.')
    return False


def run_case(case):
    evidence = ROOT / 'evidence/l18' / case / uuid.uuid4().hex
    evidence.mkdir(parents=True, exist_ok=True)
    profile = evidence / 'profile'
    profile.mkdir()
    domain = 'io.github.mpwg.Latest.NativeMigration.' + evidence.name
    migrated_directory = profile / 'Ältere Apps'
    migrated_directory.mkdir()
    legacy = (dict(directoryPaths=[str(migrated_directory), str(migrated_directory), 'relative'],
                   IgnoredAppsKey=['io.github.mpwg.Latest.LegacyIgnored'], ShowInstalledUpdatesKey=False,
                   ShowIgnoredUpdatesKey=True, ShowUnsupportedUpdatesKey=False) if case == 'valid'
              else dict(directoryPaths=['relative'], IgnoredAppsKey='invalid-array',
                        ShowInstalledUpdatesKey='invalid-boolean', ShowUnsupportedUpdatesKey='invalid-boolean'))
    old = evidence / 'legacy.plist'
    old.write_bytes(plistlib.dumps(legacy))
    preferences = profile / 'Library/Application Support/io.github.mpwg.Latest/preferences.json'
    host_preferences = Path.home() / 'Library/Application Support/io.github.mpwg.Latest/preferences.json'
    before_legacy = legacy_fingerprint()
    before_values = legacy_values()
    if before_values is not None:
        (evidence / 'ordinary-legacy-before.plist').write_bytes(plistlib.dumps(before_values))
    before_host = file_digest(host_preferences)
    (evidence / 'before.json').write_text(json.dumps(dict(legacySHA256=before_legacy, hostFileSHA256=before_host), indent=2) + '\n')
    checkpoints = {}
    subprocess.run(['defaults', 'import', domain, str(old)], check=True, capture_output=True)

    def coordinate(log):
        names = ['MIGRATED', 'EDITED', 'RESTARTED'] if case == 'valid' else ['MALFORMED', 'MALFORMED_RESTART']
        for name in names:
            marker = evidence / (name + '-ready')
            if 'L18_READY_' + name not in log or marker.exists():
                continue
            if not preferences.exists():
                raise ValueError('The actual signed app did not use its isolated normal Application Support directory.')
            value = json.loads(preferences.read_text())
            if name == 'MIGRATED':
                paths = [item['path'] for item in value['directories']]
                if paths.count(str(migrated_directory)) != 1 or 'relative' in paths:
                    raise ValueError('Legacy directories were not migrated uniquely and safely.')
                if value['ignoredBundleIDs'] != legacy['IgnoredAppsKey'] or [value['showCurrent'], value['showIgnored'], value['showUnknown']] != [False, True, False]:
                    raise ValueError('Legacy visibility/ignore values were not migrated by the normal signed app.')
            elif name in ['EDITED', 'RESTARTED']:
                if [value['showCurrent'], value['showIgnored'], value['showUnknown'], value['sortBySource']] != [True, False, True, True]:
                    return  # Native save is asynchronous; wait for its actual persisted result.
                if name == 'EDITED':
                    changed = evidence / 'changed-legacy.plist'
                    changed.write_bytes(plistlib.dumps(dict(directoryPaths=[str(profile / 'Should Not Migrate')], IgnoredAppsKey=['io.github.mpwg.Latest.ShouldNotReplace'], ShowInstalledUpdatesKey=False, ShowIgnoredUpdatesKey=True, ShowUnsupportedUpdatesKey=False)))
                    subprocess.run(['defaults', 'import', domain, str(changed)], check=True, capture_output=True)
                else:
                    if value['ignoredBundleIDs'] != legacy['IgnoredAppsKey'] or any(item['path'].endswith('Should Not Migrate') for item in value['directories']):
                        raise ValueError('A second normal start repeated legacy migration.')
            else:
                if [value['showCurrent'], value['showIgnored'], value['showUnknown']] != [True, False, True] or value['ignoredBundleIDs'] or any(item['path'] == 'relative' for item in value['directories']):
                    raise ValueError('Malformed/missing legacy fields did not use documented defaults.')
            checkpoints[name] = value
            marker.write_text('Actual normal-start migration state verified.\n')

    try:
        test = 'testNativeNormalMigrationAndPersistence' if case == 'valid' else 'testNativeMalformedLegacyFieldsUseDefaults'
        outcome = run_native_test(test, evidence, coordinate=coordinate,
                                  extra_environment=dict(LATEST_MIGRATION_PROFILE=str(profile), LATEST_MIGRATION_DOMAIN=domain, LATEST_MIGRATION_EVIDENCE=str(evidence)))
        expected = 3 if case == 'valid' else 2
        if len(checkpoints) != expected:
            raise ValueError('A required actual migration/restart checkpoint did not execute.')
        after_values = legacy_values()
        if after_values is not None:
            (evidence / 'ordinary-legacy-after.plist').write_bytes(plistlib.dumps(after_values))
        timestamp_restored = restore_legacy_check_time(before_values, evidence / 'ordinary-legacy-before.plist')
        after_legacy = legacy_fingerprint()
        after_host = file_digest(host_preferences)
        (evidence / 'after.json').write_text(json.dumps(dict(legacySHA256=after_legacy, hostFileSHA256=after_host), indent=2) + '\n')
        if before_legacy != after_legacy or before_host != after_host:
            changed_keys = [key for key in set(before_values or {}) | set(after_values or {}) if (before_values or {}).get(key) != (after_values or {}).get(key)]
            print('Changed ordinary legacy keys:', changed_keys)
            raise ValueError('An ordinary user preference domain or file changed during isolated migration.')
        result = dict(case=case, sourceRevision=fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                      macOS=fixtures.run(['sw_vers', '-productVersion'], capture=True), xcode=fixtures.run(['xcodebuild', '-version'], capture=True),
                      architecture='arm64', signingTeam=fixtures.manifest()['fixtures'][0]['team'], profile=str(profile), legacyDomain=domain,
                      launchMode='Normal signed app, no ui-testing or native-install-test-directory; filesystem home isolated and legacy CFPreferences suite aliased in Debug only.',
                      checkpoints=checkpoints, **outcome, ordinaryUserPreferencesUnchanged=True,
                      ordinaryCheckTimestampRestored=timestamp_restored,
                      sourceSHA256={str(path.relative_to(REPO)): hashlib.sha256(path.read_bytes()).hexdigest()
                                    for path in [REPO / 'Sources/LatestApp/AppModel.swift', REPO / 'Sources/LatestCore/PreferencesStore.swift', REPO / 'Tests/LatestUITests/LatestUITests.swift', Path(__file__)]})
        (evidence / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(f'Native normal migration {case}: passed; normal quits/restarts and unchanged ordinary user preferences. Evidence: {evidence}')
    finally:
        restore_legacy_check_time(before_values, evidence / 'ordinary-legacy-before.plist')
        subprocess.run(['defaults', 'delete', domain], check=True, capture_output=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('case', choices=['valid', 'malformed', 'all'])
    args = parser.parse_args()
    for case in (['valid', 'malformed'] if args.case == 'all' else [args.case]):
        run_case(case)
