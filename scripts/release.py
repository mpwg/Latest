#!/usr/bin/env python3
"""Prepare artifacts from one clean immutable source export; never publish them."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import tempfile
from appcast import MAX_FEED_BYTES, merge_feed, version_tuple
from source_snapshot import SourceSnapshot, artifact_manifest, verify_bundle, verify_source, write_source_manifest

ROOT = Path(__file__).resolve().parent.parent


def run(arguments, capture=False, input=None, cwd=None):
    result = subprocess.run(arguments, cwd=cwd or ROOT, check=True, text=True, capture_output=capture, input=input)
    return result.stdout.strip() if capture else None


def prepare_source(version):
    version_tuple(version)
    snapshot = SourceSnapshot.capture(ROOT)
    parent = ROOT / '.release/source-preparation'
    parent.mkdir(parents=True, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix=version + '-' + snapshot.revision[:12] + '-', dir=parent))
    files = snapshot.export(destination / 'source.tar.gz', destination / 'source')
    write_source_manifest(destination, snapshot, files)
    print('Prepared immutable source (no signing/notarization/publication):', destination)
    return destination


def release(version, identity, team, profile, existing_feed=None, first_release=False):
    version_tuple(version)
    if (existing_feed is not None) == first_release:
        raise ValueError('Specify exactly one of --existing-feed or --first-release; history is never silently discarded.')
    snapshot = SourceSnapshot.capture(ROOT)
    private = os.environ.get('SPARKLE_PRIVATE_KEY')
    if not private:
        raise ValueError('SPARKLE_PRIVATE_KEY is required through the environment')
    destination = ROOT / '.release' / version
    if destination.exists():
        raise ValueError('Prepared release destination already exists; it will not be overwritten.')
    work_parent = ROOT / '.release/work'
    work_parent.mkdir(parents=True, exist_ok=True)
    # Retain unsuccessful preparations for inspection. Only a complete set is renamed to the final directory.
    work = Path(tempfile.mkdtemp(prefix=version + '-', dir=work_parent))
    source = work / 'source'
    files = snapshot.export(work / 'source.tar.gz', source)
    source_manifest = write_source_manifest(work, snapshot, files)
    update = json.loads((source / 'Config/updates.json').read_text())
    run(['python3', 'scripts/bootstrap.py'], cwd=source)
    run(['swift', 'build', '-c', 'release', '--product', 'LatestRelease'], cwd=source)
    tool = source / '.build/release/LatestRelease'
    public = run([str(tool), 'public-key', '-'], capture=True, input=private, cwd=source)
    if public != update['publicKey']:
        raise ValueError('Private update key does not match the exported committed public key')
    existing = None
    if existing_feed is not None:
        path = Path(existing_feed)
        if path.stat().st_size > MAX_FEED_BYTES:
            raise ValueError('Existing appcast exceeds the feed size limit.')
        existing = path.read_bytes()
        run([str(tool), 'verify-feed', public, '-'], input=existing.decode('utf-8'), cwd=source)
    merge_feed(existing, version=version, build=snapshot.build, length=1, signature='A' * 86 + '==')
    run(['python3', 'scripts/package_app.py', '--configuration', 'release', '--identity', identity,
         '--team', team, '--public-key', public, '--version', version,
         '--build-number', snapshot.build, '--source-revision', snapshot.revision], cwd=source)
    verify_source(source, files)
    snapshot.assert_unchanged()
    app = source / '.build/release/Latest.app'
    verify_bundle(app, version=version, build=snapshot.build, revision=snapshot.revision, license_root=source)
    archive = work / 'Latest.zip'
    run(['ditto', '-c', '-k', '--keepParent', str(app), str(archive)], cwd=source)
    report = json.loads(run(['xcrun', 'notarytool', 'submit', str(archive), '--keychain-profile', profile,
                             '--wait', '--output-format', 'json'], capture=True, cwd=source))
    if report.get('status') != 'Accepted':
        raise ValueError('Notarization was not accepted; preparation is incomplete.')
    (work / 'notarization.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    run(['xcrun', 'stapler', 'staple', str(app)], cwd=source)
    run(['xcrun', 'stapler', 'validate', str(app)], cwd=source)
    run(['spctl', '--assess', '--type', 'execute', '--verbose=2', str(app)], cwd=source)
    verify_bundle(app, version=version, build=snapshot.build, revision=snapshot.revision, license_root=source)
    run(['ditto', '-c', '-k', '--keepParent', str(app), str(archive)], cwd=source)
    signature = run([str(tool), 'sign', '-', str(archive)], capture=True, input=private, cwd=source)
    unsigned = work / 'appcast-unsigned.xml'
    unsigned.write_bytes(merge_feed(existing, version=version, build=snapshot.build, length=archive.stat().st_size, signature=signature))
    run([str(tool), 'sign-feed', '-', str(unsigned), str(work / 'appcast.xml')], input=private, cwd=source)
    run([str(tool), 'verify-feed', public, str(work / 'appcast.xml')], cwd=source)
    toolchain = {name: run(command, capture=True, cwd=source) for name, command in
                 [('macOS', ['sw_vers', '-productVersion']), ('Xcode', ['xcodebuild', '-version']),
                  ('Swift', ['swift', '--version']), ('architecture', ['uname', '-m'])]}
    manifest = artifact_manifest(work, version=version, snapshot=snapshot, source_manifest=source_manifest, toolchain=toolchain)
    verify_source(source, files)
    snapshot.assert_unchanged()
    (work / 'artifact-manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    # The publication set excludes the local build workspace and unsigned intermediate feed.
    prepared = work / 'prepared'
    prepared.mkdir()
    for name in manifest['artifacts'] | {'artifact-manifest.json': None}:
        (work / name).rename(prepared / name)
    prepared.rename(destination)
    print('Prepared signed/notarized release artifacts (publication requires explicit approval):', destination)
    return destination


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', required=True)
    parser.add_argument('--prepare-source-only', action='store_true')
    parser.add_argument('--identity')
    parser.add_argument('--team')
    parser.add_argument('--notary-profile')
    history = parser.add_mutually_exclusive_group()
    history.add_argument('--existing-feed', type=Path)
    history.add_argument('--first-release', action='store_true')
    args = parser.parse_args()
    if args.prepare_source_only:
        if args.identity or args.team or args.notary_profile or args.existing_feed or args.first_release:
            parser.error('Source-only preparation does not accept signing, notarization or history options.')
        prepare_source(args.version)
    else:
        if not args.identity or not args.team or not args.notary_profile or (args.existing_feed is None and not args.first_release):
            parser.error('Release preparation requires identity, team, notary profile and explicit history selection.')
        release(args.version, args.identity, args.team, args.notary_profile, args.existing_feed, args.first_release)
