#!/usr/bin/env python3
"""Compile the actual application model/views and update only the disposable cask."""
from pathlib import Path
import hashlib
import json
import plistlib
import shutil
import subprocess
import time
import native_fixtures

REPO = native_fixtures.REPO
ROOT = native_fixtures.ROOT


def digest_app(app):
    return {str(path.relative_to(app)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(app.rglob('*')) if path.is_file() and not path.is_symlink()}


def main():
    manifest = native_fixtures.manifest()
    if not manifest['brewPrefix'] or Path(manifest['brewPrefix']) != ROOT / 'homebrew':
        raise ValueError('Prepare the isolated native fixture prefix first.')
    installed = ROOT / 'applications/Latest Homebrew Fixture.app'
    baseline = plistlib.loads((installed / 'Contents/Info.plist').read_bytes())
    if baseline['CFBundleShortVersionString'] != '1.0.0':
        raise ValueError('Reset the disposable fixtures to 1.0.0 before running positive acceptance.')
    sibling = ROOT / 'applications/Unmanaged/Latest Homebrew Fixture.app'
    sibling.parent.mkdir(exist_ok=True)
    if not sibling.exists():
        shutil.copytree(ROOT / 'versions/homebrew/1.0.0/Latest Homebrew Fixture.app', sibling)
    sibling_before = digest_app(sibling)
    sparkle = ROOT / 'applications/Latest Sparkle Fixture.app'
    sparkle_before = digest_app(sparkle)
    host_casks = native_fixtures.run(['brew', 'list', '--cask'], capture=True)
    native_fixtures.set_cask_version('1.1.0')
    native_fixtures.run(['swift', 'build'])
    binaries = Path(native_fixtures.run(['swift', 'build', '--show-bin-path'], capture=True))
    framework = REPO / 'Vendor/Sparkle/Sparkle.xcframework/macos-arm64_x86_64'
    directory = REPO / '.build/l03-native-acceptance'
    directory.mkdir(exist_ok=True)
    executable = directory / 'LatestNativeHomebrewAcceptance'
    sources = [REPO / 'Tests/NativeFixtures/HomebrewAcceptance.swift']
    sources += [REPO / 'Sources/LatestApp' / name for name in ['AppModel.swift', 'LatestWindow.swift', 'AppDetail.swift', 'LatestSettings.swift']]
    objects = []
    modules = binaries if (binaries / 'LatestCore.swiftmodule').exists() else binaries / 'Modules'
    for module in ['LatestCore', 'LatestPlatform', 'LatestProcess', 'LatestTrust', 'LatestContracts']:
        if (binaries / f'lib{module}.a').exists():
            objects.append(binaries / f'lib{module}.a')
        else:
            objects += sorted((binaries / f'{module}.build').glob('*.o'))
    native_fixtures.run(['swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
                         '-I', modules, '-F', framework, '-framework', 'Sparkle',
                         '-Xlinker', '-rpath', '-Xlinker', framework, *sources, *objects, '-o', executable])
    environment = native_fixtures.brew_environment()
    observed = set()
    process = subprocess.Popen([str(executable), str(ROOT)], cwd=REPO, env=environment)
    while process.poll() is None:
        commands = subprocess.run(['ps', '-axww', '-o', 'command='], check=True, capture_output=True, text=True).stdout.splitlines()
        for command in commands:
            if str(ROOT / 'homebrew') in command and f'upgrade --cask --no-ask {native_fixtures.TOKEN}' in command:
                observed.add(command.strip())
        time.sleep(0.05)
    if process.returncode:
        raise subprocess.CalledProcessError(process.returncode, [str(executable), str(ROOT)])
    if not observed:
        raise ValueError('The real targeted brew invocation was not observed; repeat with fresh baselines.')
    if sibling_before != digest_app(sibling) or sparkle_before != digest_app(sparkle):
        raise ValueError('An unrelated fixture app changed during the targeted update.')
    if host_casks != native_fixtures.run(['brew', 'list', '--cask'], capture=True):
        raise ValueError('The normal Homebrew cask registry changed.')
    result_path = ROOT / 'evidence/l03/result.json'
    result = json.loads(result_path.read_text())
    result.update(sourceRevision=native_fixtures.run(['git', 'rev-parse', 'HEAD'], capture=True),
                  applicationModelSHA256=hashlib.sha256((REPO / 'Sources/LatestApp/AppModel.swift').read_bytes()).hexdigest(),
                  unrelatedFixturesUnchanged=True, hostCasksUnchanged=True,
                  observedUpgradeProcesses=sorted(observed),
                  upgradeArguments=['upgrade', '--cask', '--no-ask', native_fixtures.TOKEN])
    result_path.write_text(json.dumps(result, indent=2) + '\n')
    print('Verified unrelated signed fixtures and the normal Homebrew cask registry remain unchanged.')


if __name__ == '__main__':
    main()
