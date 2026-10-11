#!/usr/bin/env python3
"""Prepare disposable, signed native apps and an isolated real Homebrew prefix."""
from pathlib import Path
import argparse
import functools
import hashlib
import http.server
import json
import os
import plistlib
import re
import shutil
import ssl
import subprocess
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parent.parent
ROOT = REPO / '.build/native-install-tests'
TOKEN = 'latest-native-fixture'
TAP = 'mpwg/latest-native-fixtures'
NAMESPACE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'


def run(arguments, capture=False, env=None):
    result = subprocess.run([str(value) for value in arguments], cwd=REPO, check=True,
                            capture_output=capture, text=True, env=env)
    return result.stdout.strip() if capture else None


def manifest():
    return json.loads((ROOT / 'manifest.json').read_text())


def save(value):
    (ROOT / 'manifest.json').write_text(json.dumps(value, indent=2) + '\n')


def brew_environment():
    # Keep the real user's HOME; all mutable Homebrew fixture paths are explicit.
    return dict(os.environ, HOMEBREW_NO_AUTO_UPDATE='1', HOMEBREW_NO_ANALYTICS='1',
                HOMEBREW_NO_INSTALL_CLEANUP='1', HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK='1',
                XDG_CONFIG_HOME=str(ROOT / 'user-config'),
                HOMEBREW_CACHE=str(ROOT / 'brew-cache'), HOMEBREW_LOGS=str(ROOT / 'brew-logs'),
                HOMEBREW_TEMP=str(ROOT / 'brew-temp'))


def write_cask(directory, version):
    archive = ROOT / 'web' / f'LatestHomebrewFixture-{version}.zip'
    text = f'''cask "{TOKEN}" do
  version "{version}"
  sha256 "{hashlib.sha256(archive.read_bytes()).hexdigest()}"
  url "{archive.as_uri()}"
  name "Latest Homebrew Fixture"
  desc "Disposable Latest native installation fixture"
  homepage "https://github.com/mpwg/Latest"
  app "Latest Homebrew Fixture.app"
end
'''
    directory.mkdir(parents=True, exist_ok=True)
    (directory / f'{TOKEN}.rb').write_text(text)


def prepare(identity, port, include_homebrew):
    if ROOT.exists():
        raise ValueError('Fixture root already exists. Verify or explicitly clean it before preparing again.')
    if identity == '-':
        raise ValueError('Native installation fixtures require an Apple signing identity, not ad-hoc signing.')
    if not 1024 <= port <= 65535:
        raise ValueError('Use an unprivileged TLS port between 1024 and 65535.')
    ROOT.mkdir(parents=True, mode=0o700)
    (ROOT / 'private').mkdir(mode=0o700)
    (ROOT / 'web').mkdir()
    (ROOT / 'applications').mkdir()
    (ROOT / 'preferences').mkdir()
    run(['swift', 'build', '--product', 'LatestRelease'])
    tool = REPO / '.build/debug/LatestRelease'
    seed = ROOT / 'private/fixture-ed25519.key'
    public_key = run([tool, 'keygen', seed], capture=True)
    executable = ROOT / 'FixtureApp'
    run(['swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
         REPO / 'Tests/NativeFixtures/FixtureApp.swift', '-o', executable])
    fixtures = []
    for source in ['Sparkle', 'Homebrew']:
        for build, version in enumerate(['1.0.0', '1.1.0'], start=1):
            app = ROOT / 'versions' / source.lower() / version / f'Latest {source} Fixture.app'
            contents = app / 'Contents'
            (contents / 'MacOS').mkdir(parents=True)
            shutil.copy2(executable, contents / 'MacOS/FixtureApp')
            info = dict(CFBundleIdentifier=f'io.github.mpwg.Latest.NativeFixture.{source}',
                        CFBundleName=f'Latest {source} Fixture', CFBundleExecutable='FixtureApp',
                        CFBundlePackageType='APPL', CFBundleShortVersionString=version,
                        CFBundleVersion=str(build), LSMinimumSystemVersion='27.0',
                        NSHighResolutionCapable=True)
            if source == 'Sparkle':
                info.update(SUFeedURL=f'https://localhost:{port}/appcast.xml', SUPublicEDKey=public_key)
            (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
            run(['codesign', '--sign', identity, '--options', 'runtime', '--timestamp=none', app])
            run(['codesign', '--verify', '--deep', '--strict', app])
            details = subprocess.run(['codesign', '-dvv', str(app)], check=True, capture_output=True, text=True).stderr
            team = re.search(r'TeamIdentifier=([A-Z0-9]{10})', details)
            authority = re.search(r'Authority=(.+)', details)
            if not team or not authority or not authority.group(1).startswith(('Apple Development:', 'Developer ID Application:')):
                raise ValueError('Fixture does not have the required own Apple signing chain.')
            archive = ROOT / 'web' / f'Latest{source}Fixture-{version}.zip'
            run(['ditto', '-c', '-k', '--keepParent', app, archive])
            fixtures.append(dict(source=source.lower(), version=version, build=str(build),
                                 bundleID=info['CFBundleIdentifier'], path=str(app), archive=str(archive),
                                 sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                                 architectures=run(['lipo', '-archs', contents / 'MacOS/FixtureApp'], capture=True),
                                 team=team.group(1), signer=authority.group(1)))
    baseline = ROOT / 'versions/sparkle/1.0.0/Latest Sparkle Fixture.app'
    shutil.copytree(baseline, ROOT / 'applications' / baseline.name)
    ET.register_namespace('sparkle', NAMESPACE)
    feed = ET.Element('rss', version='2.0')
    channel = ET.SubElement(feed, 'channel')
    ET.SubElement(channel, 'title').text = 'Latest disposable native fixtures'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = 'Fixture 1.1.0'
    ET.SubElement(item, f'{{{NAMESPACE}}}minimumSystemVersion').text = '27.0'
    archive = ROOT / 'web/LatestSparkleFixture-1.1.0.zip'
    signature = run([tool, 'sign', seed, archive], capture=True)
    ET.SubElement(item, 'enclosure', {'url': f'https://localhost:{port}/{archive.name}',
                  'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
                  f'{{{NAMESPACE}}}version': '2', f'{{{NAMESPACE}}}shortVersionString': '1.1.0',
                  f'{{{NAMESPACE}}}edSignature': signature})
    unsigned = ROOT / 'appcast-unsigned.xml'
    unsigned.write_bytes(ET.tostring(feed, encoding='utf-8', xml_declaration=True) + b'\n')
    run([tool, 'sign-feed', seed, unsigned, ROOT / 'web/appcast.xml'])
    run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-sha256', '-days', '7', '-noenc',
         '-keyout', ROOT / 'private/tls.key', '-out', ROOT / 'tls.crt', '-subj', '/CN=localhost',
         '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'], capture=True)
    (ROOT / 'private/tls.key').chmod(0o600)
    value = dict(format=1, root=str(ROOT), sourceRevision=run(['git', 'rev-parse', 'HEAD'], capture=True),
                 fixtureSourceSHA256=hashlib.sha256((REPO / 'Tests/NativeFixtures/FixtureApp.swift').read_bytes()).hexdigest(),
                 macOS=run(['sw_vers', '-productVersion'], capture=True),
                 swift=run(['swift', '--version'], capture=True), port=port, publicKey=public_key,
                 fixtures=fixtures, brewPrefix=None, tlsTrust='explicit fixture certificate only; system trust unchanged',
                 appStore='Not simulated: requires a dedicated signed Store installation, valid receipt/account and available update.')
    save(value)
    if include_homebrew:
        prepare_homebrew()
    verify()


def prepare_homebrew():
    value = manifest()
    if value['brewPrefix']:
        raise ValueError('Isolated Homebrew is already prepared.')
    source = Path(run(['brew', '--repository'], capture=True))
    prefix = ROOT / 'homebrew'
    run(['git', 'clone', '--quiet', '--shared', source, prefix])
    # Copy the runtime so automatic Ruby provisioning cannot touch the host.
    vendor = source / 'Library/Homebrew/vendor/portable-ruby'
    if vendor.exists():
        destination = prefix / 'Library/Homebrew/vendor/portable-ruby'
        if not destination.exists():
            # Never let an isolated brew auto-provision Ruby through a host symlink.
            shutil.copytree(vendor, destination, symlinks=True)
    brew = prefix / 'bin/brew'
    env = brew_environment()
    for directory in ['brew-cache', 'brew-logs', 'brew-temp', 'user-config']:
        (ROOT / directory).mkdir(exist_ok=True)
    if Path(run([brew, '--prefix'], capture=True, env=env)) != prefix:
        raise ValueError('Refusing to use a Homebrew prefix outside the disposable root.')
    tap = ROOT / 'tap'
    write_cask(tap / 'Casks', '1.0.0')
    run(['git', 'init', '--quiet', tap])
    run(['git', '-C', tap, 'add', 'Casks'])
    run(['git', '-C', tap, '-c', 'user.name=Latest Native Fixtures', '-c', 'user.email=native-fixtures@example.invalid',
         'commit', '--quiet', '-m', 'Prepare disposable fixture cask'])
    run([brew, 'tap', TAP, tap], env=env)
    run([brew, 'trust', '--cask', f'{TAP}/{TOKEN}'], env=env)
    run([brew, 'install', '--cask', '--no-ask', f'--appdir={ROOT / "applications"}', f'{TAP}/{TOKEN}'], env=env)
    value['brewPrefix'] = str(prefix)
    save(value)


def set_cask_version(version):
    value = manifest()
    if not value['brewPrefix'] or version not in ['1.0.0', '1.1.0']:
        raise ValueError('Prepare isolated Homebrew and choose an existing fixture version.')
    write_cask(Path(value['brewPrefix']) / 'Library/Taps/mpwg/homebrew-latest-native-fixtures/Casks', version)


def verify():
    value = manifest()
    for fixture in value['fixtures']:
        app = Path(fixture['path'])
        run(['codesign', '--verify', '--deep', '--strict', app])
        metadata = json.loads(run([app / 'Contents/MacOS/FixtureApp', '--fixture-metadata'], capture=True))
        if metadata['version'] != fixture['version'] or metadata['bundleID'] != fixture['bundleID']:
            raise ValueError('Native executable and prepared fixture metadata differ.')
        if hashlib.sha256(Path(fixture['archive']).read_bytes()).hexdigest() != fixture['sha256']:
            raise ValueError('Prepared fixture archive changed.')
    if value['brewPrefix']:
        brew = Path(value['brewPrefix']) / 'bin/brew'
        result = json.loads(run([brew, 'info', '--cask', '--json=v2', '--installed'], capture=True, env=brew_environment()))
        casks = result['casks']
        if len(casks) != 1 or casks[0]['token'] != TOKEN or not casks[0]['installed']:
            raise ValueError('Isolated prefix does not contain exactly the disposable fixture cask.')
    print(f'Verified {len(value["fixtures"])} Apple-signed native bundles; isolated Homebrew: {bool(value["brewPrefix"])}.')


def serve():
    value = manifest()
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT / 'web'))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', value['port']), handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(ROOT / 'tls.crt', ROOT / 'private/tls.key')
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print(f'Fixture HTTPS server: https://localhost:{value["port"]}/ (loopback only)', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def trust_localhost():
    value = manifest()
    if value.get('trustedKeychain'):
        raise ValueError('This fixture certificate is already recorded as trusted.')
    keychain = run(['security', 'default-keychain', '-d', 'user'], capture=True).strip('"')
    # The explicit command opts into user-domain SSL trust for localhost only.
    value['trustedKeychain'] = keychain
    save(value)
    run(['security', 'add-trusted-cert', '-r', 'trustRoot', '-p', 'ssl', '-s', 'localhost',
         '-k', keychain, ROOT / 'tls.crt'])
    value['tlsTrust'] = 'user-domain SSL trust constrained to localhost; remove after tests'
    save(value)


def untrust_localhost():
    value = manifest()
    keychain = value.get('trustedKeychain')
    if not keychain:
        return
    certificate = ROOT / 'tls.crt'
    fingerprint = run(['openssl', 'x509', '-in', certificate, '-noout', '-fingerprint', '-sha256'], capture=True)
    fingerprint = fingerprint.split('=', 1)[1].replace(':', '')
    # A failed initial trust operation may have left no trust setting/certificate.
    for arguments in [['security', 'remove-trusted-cert', certificate],
                      ['security', 'delete-certificate', '-Z', fingerprint, keychain]]:
        result = subprocess.run([str(value) for value in arguments], capture_output=True, text=True)
        if result.returncode and 'could not be found' not in result.stderr.lower() and 'no trust settings' not in result.stderr.lower():
            raise RuntimeError(result.stderr.strip())
    value.pop('trustedKeychain')
    value['tlsTrust'] = 'explicit fixture certificate only; system trust unchanged'
    save(value)


def cleanup():
    value = manifest()
    if ROOT.is_symlink() or value['format'] != 1 or value['root'] != str(ROOT):
        raise ValueError('Refusing cleanup outside the generated disposable root.')
    if value['brewPrefix']:
        prefix = Path(value['brewPrefix'])
        if prefix != ROOT / 'homebrew' or prefix.is_symlink():
            raise ValueError('Unexpected Homebrew prefix; refusing cleanup.')
        run([prefix / 'bin/brew', 'uninstall', '--cask', TOKEN], env=brew_environment())
    untrust_localhost()
    shutil.rmtree(ROOT)
    print('Removed only the generated native fixture root; host Homebrew and production apps unchanged.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    preparation = commands.add_parser('prepare')
    preparation.add_argument('--identity', required=True)
    preparation.add_argument('--port', type=int, default=8443)
    preparation.add_argument('--homebrew', action='store_true')
    for name in ['verify', 'serve', 'cleanup', 'prepare-homebrew', 'trust-localhost', 'untrust-localhost']:
        commands.add_parser(name)
    version = commands.add_parser('set-cask-version')
    version.add_argument('version', choices=['1.0.0', '1.1.0'])
    arguments = parser.parse_args()
    if arguments.command == 'prepare':
        prepare(arguments.identity, arguments.port, arguments.homebrew)
    elif arguments.command == 'prepare-homebrew':
        prepare_homebrew()
    elif arguments.command == 'set-cask-version':
        set_cask_version(arguments.version)
    else:
        {'verify': verify, 'serve': serve, 'cleanup': cleanup,
         'trust-localhost': trust_localhost, 'untrust-localhost': untrust_localhost}[arguments.command]()
