"""Actual Git export and release binding regressions; no GUI or production credentials."""
import base64
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import tarfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from appcast import merge_feed
import package_app
import release
from source_snapshot import SourceSnapshot, artifact_manifest, digest, verify_bundle, verify_source, write_source_manifest

SIGNATURE = base64.b64encode(bytes(64)).decode()
TRAILER = 'Co-authored-by: Codex <codex@openai.com>'


def git(root, *arguments):
    return subprocess.check_output(['git', *arguments], cwd=root, text=True, stderr=subprocess.STDOUT).strip()


def fixture_repository(root):
    root.mkdir()
    git(root, 'init', '--quiet')
    (root / '.gitignore').write_text('.release/\n.build/\nVendor/\n')
    (root / 'Config').mkdir(); (root / 'scripts').mkdir()
    (root / 'Config/dependencies.json').write_text(json.dumps({'sparkle': {'sha256': 'pinned'}, 'mas': {'revision': 'pinned'}}))
    (root / 'Config/updates.json').write_text(json.dumps({'publicKey': 'test-public-key'}))
    (root / 'scripts/one.patch').write_text('Controlled reviewed dependency patch.\n')
    (root / 'LICENSE.md').write_text('Controlled GPL licence notice.\n')
    (root / 'source.swift').write_text('let original = 1\n')
    commit(root, 'Initial source fixture')
    return root


def commit(root, message):
    git(root, 'add', '.')
    git(root, '-c', 'user.name=Latest Test Fixture', '-c', 'user.email=fixture@example.invalid',
        'commit', '--quiet', '-m', message, '-m', TRAILER)


def bundle(path, *, revision, build, version='1.0.0'):
    contents = path / 'Contents'
    (contents / 'Resources').mkdir(parents=True)
    (contents / 'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='io.github.mpwg.Latest',
        CFBundleShortVersionString=version, CFBundleVersion=build, LatestSourceRevision=revision)))
    for name in ['LICENSE.md', 'Sparkle-LICENSE.txt', 'mas-LICENSE.txt']:
        (contents / 'Resources' / name).write_text('Controlled licence.\n')
    return path


class FrozenSourceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='latest-source-')
        self.root = fixture_repository(Path(self.temporary.name) / 'repository')

    def tearDown(self):
        self.temporary.cleanup()

    def test_dirty_staged_untracked_and_tracked_private_inputs_rejected(self):
        for mode in ['unstaged', 'staged', 'untracked', 'private']:
            root = fixture_repository(Path(self.temporary.name) / mode)
            if mode in ['unstaged', 'staged']:
                (root / 'source.swift').write_text('let uncommitted = 2\n')
                if mode == 'staged': git(root, 'add', 'source.swift')
            elif mode == 'untracked':
                (root / 'forgotten.swift').write_text('untracked\n')
            else:
                (root / 'credential.key').write_text('independent dummy data\n'); commit(root, 'Forbidden tracked credential fixture')
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                SourceSnapshot.capture(root)
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'run') as runner:
            (self.root / 'source.swift').write_text('dirty\n')
            with self.assertRaises(ValueError): release.release('1.0.0', 'identity', 'team', 'profile', first_release=True)
            runner.assert_not_called()

    def test_export_is_exact_reproducible_commit_and_excludes_private_data(self):
        private = self.root / '.release'; private.mkdir()
        (private / 'dummy.key').write_text('Independent ignored private fixture.\n')
        snapshot = SourceSnapshot.capture(self.root)
        exports = self.root / '.release/exports'; exports.mkdir()
        first = exports / 'source.tar.gz'; second = exports / 'again.tar.gz'
        expected = snapshot.export(first, exports / 'one')
        repeated = snapshot.export(second, exports / 'two')
        self.assertEqual(expected, repeated); self.assertEqual(digest(first), digest(second))
        self.assertEqual(expected['source.swift']['sha256'], digest(self.root / 'source.swift')['sha256'])
        self.assertNotIn('.release/dummy.key', expected)
        self.assertFalse((exports / 'one/.git').exists())
        (self.root / 'source.swift').write_text('let later = 3\n'); commit(self.root, 'Later source fixture')
        self.assertEqual((exports / 'one/source.swift').read_text(), 'let original = 1\n')
        with self.assertRaises(ValueError): snapshot.assert_unchanged()

    def test_build_outputs_allowed_but_exported_source_tamper_or_addition_rejected(self):
        snapshot = SourceSnapshot.capture(self.root)
        exports = self.root / '.release/exports'; exports.mkdir(parents=True)
        workspace = exports / 'source'
        expected = snapshot.export(exports / 'source.tar.gz', workspace)
        for folder in ['Vendor', '.build', 'scripts/__pycache__']:
            generated = workspace / folder; generated.mkdir(parents=True)
            (generated / 'generated').write_text('Local build output.\n')
        verify_source(workspace, expected)
        (workspace / 'unexpected.swift').write_text('Injected source.\n')
        with self.assertRaises(ValueError): verify_source(workspace, expected)
        (workspace / 'unexpected.swift').unlink()
        (workspace / 'source.swift').write_text('Changed exported input.\n')
        with self.assertRaises(ValueError): verify_source(workspace, expected)

    def test_source_archive_cannot_export_external_symlink(self):
        (self.root / 'external').symlink_to('/etc/passwd'); commit(self.root, 'External symlink fixture')
        snapshot = SourceSnapshot.capture(self.root)
        with self.assertRaises(tarfile.AbsoluteLinkError):
            snapshot.export(self.root / '.release/source.tar.gz', self.root / '.release/source')
        self.assertFalse((self.root / '.release/source/external').exists())

    def test_packaging_requires_fixed_identity_for_release_and_rejects_partial_values(self):
        revision = 'a' * 40
        self.assertEqual(package_app.package_identity('release', '10', revision), ('10', revision))
        for build, commit_id in [(None, None), ('10', None), (None, revision), ('01', revision), ('10', 'HEAD')]:
            with self.subTest(build=build, revision=commit_id), self.assertRaises(ValueError):
                package_app.package_identity('release', build, commit_id)
        app = bundle(Path(self.temporary.name) / 'Latest.app', revision=revision, build='10')
        verify_bundle(app, version='1.0.0', build='10', revision=revision)
        for values in [dict(version='2.0.0', build='10', revision=revision),
                       dict(version='1.0.0', build='11', revision=revision),
                       dict(version='1.0.0', build='10', revision='b' * 40)]:
            with self.subTest(values=values), self.assertRaises(ValueError): verify_bundle(app, **values)
        (app / 'Contents/Resources/mas-LICENSE.txt').unlink()
        with self.assertRaises(ValueError): verify_bundle(app, version='1.0.0', build='10', revision=revision)

    def prepared_metadata(self):
        snapshot = SourceSnapshot.capture(self.root)
        directory = self.root / '.release/metadata'; directory.mkdir(parents=True)
        files = snapshot.export(directory / 'source.tar.gz', directory / 'source')
        source = write_source_manifest(directory, snapshot, files)
        (directory / 'Latest.zip').write_bytes(b'Controlled final archive bytes.')
        (directory / 'appcast.xml').write_bytes(merge_feed(None, version='1.0.0', build=snapshot.build,
            length=(directory / 'Latest.zip').stat().st_size, signature=SIGNATURE))
        (directory / 'notarization.json').write_text(json.dumps({'status': 'Accepted', 'id': 'controlled-fixture'}))
        return snapshot, directory, source

    def test_manifest_binds_source_archive_appcast_length_build_pins_and_patch_hashes(self):
        snapshot, directory, source = self.prepared_metadata()
        manifest = artifact_manifest(directory, version='1.0.0', snapshot=snapshot, source_manifest=source, toolchain={'test': True})
        self.assertEqual(manifest['sourceRevision'], snapshot.revision)
        self.assertEqual(manifest['build'], snapshot.build)
        self.assertEqual(manifest['dependencies'], source['dependencies'])
        self.assertEqual(manifest['patches']['one.patch'], digest(self.root / 'scripts/one.patch'))
        self.assertEqual(manifest['artifacts']['Latest.zip'], digest(directory / 'Latest.zip'))
        self.assertFalse(manifest['published'])
        for filename in ['Latest.zip', 'source.tar.gz', 'source-revision.txt', 'source-manifest.json', 'notarization.json']:
            path = directory / filename; original = path.read_bytes(); path.write_bytes(original + b'corrupt')
            with self.subTest(filename=filename), self.assertRaises((ValueError, json.JSONDecodeError)):
                artifact_manifest(directory, version='1.0.0', snapshot=snapshot, source_manifest=source, toolchain={})
            path.write_bytes(original)
        (directory / 'appcast.xml').write_bytes(merge_feed(None, version='1.0.0', build=int(snapshot.build) + 1,
            length=(directory / 'Latest.zip').stat().st_size, signature=SIGNATURE))
        with self.assertRaises(ValueError): artifact_manifest(directory, version='1.0.0', snapshot=snapshot, source_manifest=source, toolchain={})

    def test_release_pipeline_uses_frozen_workspace_and_only_final_publication_files(self):
        calls = []
        notary_status = 'Accepted'
        snapshot = SourceSnapshot.capture(self.root)

        def operation(arguments, capture=False, input=None, cwd=None):
            arguments = list(map(str, arguments)); cwd = Path(cwd); calls.append((arguments, cwd, input))
            self.assertNotEqual(cwd, self.root)
            self.assertEqual(cwd.name, 'source')
            if arguments[:2] == ['python3', 'scripts/package_app.py']:
                actual_build = arguments[arguments.index('--build-number') + 1]
                actual_revision = arguments[arguments.index('--source-revision') + 1]
                app = bundle(cwd / '.build/release/Latest.app', revision=actual_revision, build=actual_build)
                # The real packaging path copies these notices from pinned sources/distributions.
                (app / 'Contents/Resources/LICENSE.md').write_bytes((cwd / 'LICENSE.md').read_bytes())
                for component in ['Sparkle', 'mas']:
                    vendor = cwd / 'Vendor' / component; vendor.mkdir(parents=True, exist_ok=True)
                    (vendor / 'LICENSE').write_text('Controlled dependency licence.\n')
                    (app / 'Contents/Resources' / (component + '-LICENSE.txt')).write_bytes((vendor / 'LICENSE').read_bytes())
            elif arguments[0] == 'ditto':
                Path(arguments[-1]).write_bytes(b'Controlled final signed/stapled archive stand-in.')
            elif 'public-key' in arguments:
                return 'test-public-key'
            elif 'notarytool' in arguments:
                return json.dumps({'status': notary_status, 'id': 'controlled-notary-fixture'})
            elif 'sign-feed' in arguments:
                Path(arguments[-1]).write_bytes(Path(arguments[-2]).read_bytes())
            elif 'sign' in arguments:
                return SIGNATURE
            return 'Controlled toolchain.' if capture else None

        with patch.object(release, 'ROOT', self.root), patch.object(release, 'run', side_effect=operation), \
             patch.dict('os.environ', {'SPARKLE_PRIVATE_KEY': 'independent-unit-fixture'}, clear=False), patch('builtins.print'):
            destination = release.release('1.0.0', 'identity', 'team', 'profile', first_release=True)
        manifest = json.loads((destination / 'artifact-manifest.json').read_text())
        self.assertEqual(manifest['sourceRevision'], snapshot.revision)
        self.assertEqual({path.name for path in destination.iterdir()}, set(manifest['artifacts']) | {'artifact-manifest.json'})
        self.assertNotIn('source', manifest['artifacts']); self.assertFalse((destination / 'appcast-unsigned.xml').exists())
        self.assertTrue(any('spctl' in command for command, _, _ in calls))
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'run') as runner, \
             patch.dict('os.environ', {'SPARKLE_PRIVATE_KEY': 'independent-unit-fixture'}, clear=False):
            with self.assertRaises(ValueError): release.release('1.0.0', 'identity', 'team', 'profile', first_release=True)
            runner.assert_not_called()

        rejected = fixture_repository(Path(self.temporary.name) / 'rejected-notary')
        notary_status = 'Invalid'; calls.clear()
        with patch.object(release, 'ROOT', rejected), patch.object(release, 'run', side_effect=operation), \
             patch.dict('os.environ', {'SPARKLE_PRIVATE_KEY': 'independent-unit-fixture'}, clear=False):
            with self.assertRaisesRegex(ValueError, 'Notarization was not accepted'):
                release.release('1.0.0', 'identity', 'team', 'profile', first_release=True)
        self.assertFalse((rejected / '.release/1.0.0').exists())
        self.assertFalse(any('stapler' in command or 'spctl' in command for command, _, _ in calls))


if __name__ == '__main__':
    unittest.main()
