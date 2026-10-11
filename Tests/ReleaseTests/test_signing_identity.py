"""Portable certificate selection regressions; native signing has a separate proof."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
import package_app

FINGERPRINT = 'A' * 40
NAME = 'Apple Development: Example Géhri (EXAMPLETEAM)'
IDENTITIES = f'  1) {FINGERPRINT} "{NAME}"\n  1 valid identities found\n'


class SigningIdentityTests(unittest.TestCase):
    def test_unicode_full_name_and_case_insensitive_fingerprint_select_same_certificate(self):
        for requested in [NAME, FINGERPRINT, FINGERPRINT.lower()]:
            with self.subTest(requested=requested):
                self.assertEqual(package_app.select_signing_identity(requested, IDENTITIES), FINGERPRINT)
        # Duplicate keychain listings of the same certificate are one identity.
        self.assertEqual(package_app.select_signing_identity(NAME, IDENTITIES + IDENTITIES), FINGERPRINT)

    def test_missing_partial_malformed_and_ambiguous_selection_are_rejected(self):
        ambiguous = IDENTITIES + f'  2) {"B" * 40} "{NAME}"\n'
        for requested, available in [(NAME, ''), ('Example Géhri', IDENTITIES),
                                     (NAME, f'1) BAD "{NAME}"'), (NAME, ambiguous),
                                     ('C' * 40, IDENTITIES)]:
            with self.subTest(requested=requested, available=available), self.assertRaises(ValueError):
                package_app.select_signing_identity(requested, available)

    def test_adhoc_bypasses_keychain_lookup_and_named_selection_queries_only_existing_identities(self):
        with patch.object(package_app, 'run', return_value=IDENTITIES) as runner:
            self.assertEqual(package_app.resolve_signing_identity('-'), '-')
            runner.assert_not_called()
            self.assertEqual(package_app.resolve_signing_identity(NAME), FINGERPRINT)
            runner.assert_called_once_with(['security', 'find-identity', '-v', '-p', 'codesigning'], capture=True)

    def test_unavailable_identity_fails_before_build_or_replacing_generated_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / '.build/debug/Latest.app/marker'
            marker.parent.mkdir(parents=True)
            marker.write_text('Keep existing generated bundle.\n')
            with patch.object(package_app, 'ROOT', root), patch.object(package_app, 'run', return_value='') as runner:
                with self.assertRaises(ValueError):
                    package_app.package('debug', NAME, 'EXAMPLETEAM', '', '1.0.0', '1', 'a' * 40)
                runner.assert_called_once_with(['security', 'find-identity', '-v', '-p', 'codesigning'], capture=True)
            self.assertEqual(marker.read_text(), 'Keep existing generated bundle.\n')
