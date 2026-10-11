"""Freeze a clean Git revision and verify its exported source and release metadata."""
from dataclasses import dataclass
from pathlib import Path
import hashlib
import json
import os
import plistlib
import re
import subprocess
import tarfile
import xml.etree.ElementTree as ET
from appcast import SPARKLE, validate_enclosure


def git(root, *arguments):
    return subprocess.check_output(['git', *arguments], cwd=root, text=True).strip()


def digest(path):
    data = Path(path).read_bytes()
    return dict(length=len(data), sha256=hashlib.sha256(data).hexdigest())


def source_files(root):
    result = {}
    root = Path(root)
    for directory, directories, names in os.walk(root):
        base = Path(directory)
        if base == root:
            directories[:] = [name for name in directories if name not in ['.build', '.git', '.swiftpm', 'Vendor']]
        directories[:] = [name for name in directories if name != '__pycache__']
        for name in sorted(names + directories):
            path = base / name
            relative = path.relative_to(root)
            if path.is_symlink():
                result[str(relative)] = dict(kind='symlink', target=str(path.readlink()))
            elif path.is_file():
                result[str(relative)] = dict(kind='file', **digest(path))
    return result


@dataclass(frozen=True)
class SourceSnapshot:
    root: Path
    revision: str
    build: str

    @classmethod
    def capture(cls, root):
        root = Path(root).resolve()
        if Path(git(root, 'rev-parse', '--show-toplevel')).resolve() != root:
            raise ValueError('Release input must be the Git repository root.')
        revision = git(root, 'rev-parse', '--verify', 'HEAD^{commit}')
        if git(root, 'status', '--porcelain=v1', '--untracked-files=all'):
            raise ValueError('Release input has staged, unstaged or untracked changes.')
        build = git(root, 'rev-list', '--count', revision)
        if not re.fullmatch(r'[0-9a-f]{40}|[0-9a-f]{64}', revision) or not re.fullmatch(r'[1-9][0-9]*', build):
            raise ValueError('Invalid immutable source identity.')
        tracked = git(root, 'ls-tree', '-r', '--name-only', revision).splitlines()
        if any(Path(path).parts[0] in ['.release', '.build', 'Vendor'] or
               path.endswith(('.p12', '.p8', '.key')) or Path(path).name in ['.env', '.env.local'] for path in tracked):
            raise ValueError('Private/generated release material must not be tracked in the source archive.')
        snapshot = cls(root, revision, build)
        snapshot.assert_unchanged()
        return snapshot

    def assert_unchanged(self):
        if git(self.root, 'rev-parse', '--verify', 'HEAD^{commit}') != self.revision or git(self.root, 'status', '--porcelain=v1', '--untracked-files=all'):
            raise ValueError('Original source revision or working tree changed during release preparation.')

    def export(self, archive, workspace):
        archive, workspace = Path(archive), Path(workspace)
        archive.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', 'archive', '--format=tar.gz', '--output', str(archive.resolve()), self.revision], cwd=self.root, check=True)
        workspace.mkdir(parents=True, exist_ok=False)
        with tarfile.open(archive) as source:
            source.extractall(workspace, filter='data')
        files = source_files(workspace)
        if any(Path(path).parts[0] == '.release' for path in files):
            raise ValueError('Private release directory reached source export.')
        self.assert_unchanged()
        return files


def verify_source(workspace, expected):
    if source_files(workspace) != expected:
        raise ValueError('Exported tracked source changed or unaccounted files were added during build.')


def verify_bundle(app, *, version, build, revision, license_root=None):
    info = plistlib.loads((Path(app) / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'io.github.mpwg.Latest' or info.get('CFBundleShortVersionString') != version or info.get('CFBundleVersion') != build or info.get('LatestSourceRevision') != revision:
        raise ValueError('Packaged bundle version/build/source identity does not match the frozen input.')
    for name in ['LICENSE.md', 'Sparkle-LICENSE.txt', 'mas-LICENSE.txt']:
        path = Path(app) / 'Contents/Resources' / name
        if not path.is_file() or not path.stat().st_size:
            raise ValueError('A required application/dependency licence notice is absent.')
        if license_root is not None:
            original = {'LICENSE.md': 'LICENSE.md', 'Sparkle-LICENSE.txt': 'Vendor/Sparkle/LICENSE', 'mas-LICENSE.txt': 'Vendor/mas/LICENSE'}[name]
            if digest(path) != digest(Path(license_root) / original):
                raise ValueError('Packaged licence differs from the pinned source/distribution licence.')
    return info


def artifact_manifest(directory, *, version, snapshot, source_manifest, toolchain):
    directory = Path(directory)
    archive, feed = directory / 'Latest.zip', directory / 'appcast.xml'
    metadata = digest(archive)
    items = ET.fromstring(feed.read_bytes()).findall('./channel/item/enclosure')
    current = [item for item in items if item.get(f'{{{SPARKLE}}}shortVersionString') == version]
    if len(current) != 1:
        raise ValueError('Prepared appcast must contain exactly one current release.')
    actual_version, actual_build = validate_enclosure(current[0])
    if actual_version != version or str(actual_build) != snapshot.build or current[0].get('length') != str(metadata['length']):
        raise ValueError('Prepared appcast does not match the frozen bundle/archive metadata.')
    if (directory / 'source-revision.txt').read_text().strip() != snapshot.revision:
        raise ValueError('Source revision sidecar changed.')
    if json.loads((directory / 'source-manifest.json').read_text()) != source_manifest:
        raise ValueError('Source manifest changed during preparation.')
    if json.loads((directory / 'notarization.json').read_text()).get('status') != 'Accepted':
        raise ValueError('Prepared notarization report is not Accepted.')
    if digest(directory / 'source.tar.gz') != source_manifest['archive']:
        raise ValueError('Exported source archive changed.')
    artifacts = {name: digest(directory / name) for name in
                 ['Latest.zip', 'appcast.xml', 'source.tar.gz', 'source-revision.txt', 'source-manifest.json', 'notarization.json']}
    return dict(format=1, version=version, build=snapshot.build, sourceRevision=snapshot.revision,
                artifacts=artifacts, dependencies=source_manifest['dependencies'], patches=source_manifest['patches'],
                toolchain=toolchain, published=False)


def write_source_manifest(directory, snapshot, files):
    directory = Path(directory)
    workspace = directory / 'source'
    data = dict(format=1, sourceRevision=snapshot.revision, build=snapshot.build,
                archive=digest(directory / 'source.tar.gz'), files=files,
                dependencies=json.loads((workspace / 'Config/dependencies.json').read_text()),
                patches={path.name: digest(path) for path in sorted((workspace / 'scripts').glob('*.patch'))})
    (directory / 'source-revision.txt').write_text(snapshot.revision + '\n')
    (directory / 'source-manifest.json').write_text(json.dumps(data, indent=2, sort_keys=True) + '\n')
    return data
