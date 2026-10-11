"""Own-fork history and whole-feed signing regressions; no release credentials."""
import base64
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from appcast import MAX_FEED_BYTES, SPARKLE, merge_feed

SIGNATURE = base64.b64encode(bytes(range(64))).decode()


def merge(existing=None, version='1.0.0', build=10, **overrides):
    values = dict(version=version, build=build, length=123, signature=SIGNATURE)
    values.update(overrides)
    return merge_feed(existing, **values)


class AppcastHistoryTests(unittest.TestCase):
    def test_initial_and_empty_channel(self):
        initial = merge()
        rss = ET.fromstring(initial)
        self.assertEqual(len(rss.findall('./channel/item')), 1)
        rss.find('channel').remove(rss.find('./channel/item'))
        self.assertEqual(len(ET.fromstring(merge(ET.tostring(rss))).findall('./channel/item')), 1)

    def test_history_preserves_notes_extensions_and_newest_first(self):
        rss = ET.fromstring(merge())
        first = rss.find('./channel/item')
        ET.SubElement(first, 'description').text = 'Ältere Hinweise: <p>retain this</p>'
        ET.SubElement(first, f'{{{SPARKLE}}}releaseNotesLink').text = 'https://example.org/notes'
        existing = ET.tostring(rss)
        second = merge(existing, '1.1.0', 11)
        final = ET.fromstring(merge(second, '1.2.0', 12))
        items = final.findall('./channel/item')
        self.assertEqual([item.find('enclosure').get(f'{{{SPARKLE}}}version') for item in items], ['12', '11', '10'])
        self.assertEqual(ET.tostring(items[2]), ET.tostring(first))
        self.assertEqual(final.find('./channel/title').text, rss.find('./channel/title').text)

    def test_duplicate_and_nonadvancing_release_is_rejected(self):
        history = merge()
        for version, build in [('1.0.0', 11), ('1.1.0', 10), ('0.9.0', 11), ('1.1.0', 9)]:
            with self.subTest(version=version, build=build), self.assertRaises(ValueError):
                merge(history, version, build)
        rss = ET.fromstring(history)
        rss.find('channel').append(ET.fromstring(ET.tostring(rss.find('./channel/item'))))
        with self.assertRaises(ValueError):
            merge(ET.tostring(rss), '1.1.0', 11)

    def test_malformed_or_foreign_history_is_rejected(self):
        for history in [b'', b'<rss>', b'<rss version="2.0"><channel/><channel/></rss>',
                        b'<!DOCTYPE rss [<!ENTITY x "test">]><rss version="2.0"><channel/></rss>',
                        '<!DOCTYPE rss [<!ENTITY x "test">]><rss/>'.encode('utf-16'),
                        b'x' * (MAX_FEED_BYTES + 1)]:
            with self.subTest(history=history[:60]), self.assertRaises(ValueError):
                merge(history)
        rss = ET.fromstring(merge())
        rss.find('./channel/link').text = 'https://github.com/mangerlahn/Latest'
        with self.assertRaises(ValueError):
            merge(ET.tostring(rss), '1.1.0', 11)

    def test_inconsistent_archive_metadata_is_rejected(self):
        for attribute, value in [('url', 'http://github.com/mpwg/Latest/Latest.zip'), ('length', '0'),
                                 ('type', 'text/html'), (f'{{{SPARKLE}}}edSignature', 'invalid'),
                                 (f'{{{SPARKLE}}}version', '01'), (f'{{{SPARKLE}}}shortVersionString', '01.0.0')]:
            rss = ET.fromstring(merge())
            rss.find('./channel/item/enclosure').set(attribute, value)
            with self.subTest(attribute=attribute), self.assertRaises(ValueError):
                merge(ET.tostring(rss), '1.1.0', 11)
        for overrides in [dict(length=0), dict(signature='invalid'), dict(build=-1)]:
            with self.subTest(overrides=overrides), self.assertRaises(ValueError):
                merge(**overrides)

    def test_historical_version_build_order_and_missing_enclosure(self):
        history = ET.fromstring(merge(merge(), '1.1.0', 11))
        enclosures = history.findall('./channel/item/enclosure')
        enclosures[0].set(f'{{{SPARKLE}}}version', '9')
        with self.assertRaises(ValueError):
            merge(ET.tostring(history), '1.2.0', 12)
        item = history.find('./channel/item')
        item.remove(item.find('enclosure'))
        with self.assertRaises(ValueError):
            merge(ET.tostring(history), '1.2.0', 12)

class AppcastSigningIntegrationTests(unittest.TestCase):
    def test_actual_signed_history_and_resigned_merged_feed(self):
        tool = ROOT / '.build/debug/LatestRelease'
        self.assertTrue(tool.is_file(), 'Build LatestRelease before running signing integration tests.')
        with tempfile.TemporaryDirectory(prefix='latest-appcast-') as temporary:
            directory = Path(temporary)
            seed = directory / 'fixture-key'
            public = subprocess.check_output([tool, 'keygen', seed], text=True).strip()
            first = directory / 'first.xml'
            first.write_bytes(merge())
            signed = directory / 'signed.xml'
            subprocess.run([tool, 'sign-feed', seed, first, signed], check=True)
            subprocess.run([tool, 'verify-feed', public, signed], check=True)
            first_signed = signed.read_bytes()
            subprocess.run([tool, 'verify-feed', public, '-'], input=first_signed, check=True)
            second = directory / 'merged.xml'
            second.write_bytes(merge(first_signed, '1.1.0', 11))
            subprocess.run([tool, 'sign-feed', seed, second, signed], check=True)
            subprocess.run([tool, 'verify-feed', public, signed], check=True)
            final_signed = signed.read_bytes()
            self.assertEqual(final_signed.count(b'<!-- sparkle-signatures:'), 1)
            self.assertEqual(len(ET.fromstring(final_signed).findall('./channel/item')), 2)
            for corrupt in [final_signed.replace(b'Latest 1.0.0', b'Latest 9.0.0'), final_signed + b'junk',
                            final_signed.replace(b'length: ', b'length: 1'), second.read_bytes(),
                            final_signed + first_signed[first_signed.index(b'<!-- sparkle-signatures:'):]]:
                signed.write_bytes(corrupt)
                result = subprocess.run([tool, 'verify-feed', public, signed], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
            other = directory / 'other-key'
            other_public = subprocess.check_output([tool, 'keygen', other], text=True).strip()
            signed.write_bytes(final_signed)
            self.assertNotEqual(subprocess.run([tool, 'verify-feed', other_public, signed], capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main()
