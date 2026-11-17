#!/usr/bin/env python3
"""Offline locale integrity/coverage gates; no third-party dependencies."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
LOCALES = {'en_US', 'en_GB', 'en_AU', 'fr_CA', 'es_ES', 'es_MX', 'de_DE', 'it_IT', 'pt_BR'}
NS = {'x': 'urn:oasis:names:tc:xliff:document:1.2'}

def required_sources():
    sources = {"AM", "PM"}
    for path in (ROOT / 'components').rglob('*.brs'):
        sources.update(re.findall(r'\btr\(\s*"([^"\n]*)"\s*\)', path.read_text(), re.I))
    for entry in json.loads((ROOT / 'config/changelog.json').read_text()):
        sources.add(entry['title'])
        sources.update(entry['message'])
    sources.update(row[0] for row in json.loads((ROOT / 'config/location/countries.json').read_text()))
    return sources

def catalogs():
    return {path.parent.name: ET.parse(path).getroot() for path in (ROOT / 'locale').glob('*/translations.xml')}

class CatalogTests(unittest.TestCase):
    def test_supported_locales(self):
        self.assertEqual(set(catalogs()), LOCALES)

    def test_valid_complete_catalogs(self):
        required = required_sources()
        self.assertGreater(len(required), 250)
        for locale, root in catalogs().items():
            with self.subTest(locale=locale):
                self.assertEqual(root.tag, '{'+NS['x']+'}xliff')
                self.assertEqual(root.attrib['version'], '1.2')
                files = root.findall('x:file', NS)
                self.assertEqual(len(files), 1)
                self.assertEqual(files[0].attrib['source-language'].replace('_', '-'), 'en-US')
                self.assertEqual(files[0].attrib['target-language'].replace('_', '-'), locale.replace('_', '-'))
                entries = root.findall('.//x:trans-unit', NS)
                sources, ids = [], []
                for entry in entries:
                    source = entry.findtext('x:source', namespaces=NS)
                    target = entry.findtext('x:target', namespaces=NS)
                    self.assertTrue(source and source.strip(), (locale, entry.attrib))
                    self.assertTrue(target and target.strip(), (locale, source))
                    self.assertEqual(Counter(re.findall(r'%\d+', source)), Counter(re.findall(r'%\d+', target)), (locale, source))
                    self.assertNotIn('\ufffd', target, (locale, source))
                    sources.append(source)
                    ids.append(entry.attrib['id'])
                self.assertEqual(len(sources), len(set(sources)), locale)
                self.assertEqual(len(ids), len(set(ids)), locale)
                self.assertFalse(required - set(sources), (locale, sorted(required-set(sources))))

    def test_canadian_english_uses_source_fallback(self):
        self.assertFalse((ROOT / "locale/en_CA").exists())
        self.assertIn("en_CA", (ROOT / "preview/main.ts").read_text())
        self.assertIn('if (locale === "en_CA") return source;', (ROOT / "tests/visual/localization.spec.ts").read_text())

    def test_location_data_unchanged(self):
        # Translation changes displayed country names, never dataset order/IDs/coordinates.
        baseline = json.loads((ROOT / 'tools/localization/location_baseline.json').read_text())
        for relative, digest in baseline.items():
            self.assertEqual(hashlib.sha256((ROOT / relative).read_bytes()).hexdigest(), digest, relative)

    def test_packaging_and_preview_include_locales(self):
        for filename in ('bsconfig.json', 'bsconfig.check.json'):
            self.assertIn('locale/**/*', json.loads((ROOT / filename).read_text())['files'])
        self.assertIn('"locale"', (ROOT / 'preview/vite.config.ts').read_text())
        self.assertIn('locale/*', (ROOT / 'tools/zip_check.sh').read_text())
        self.assertIn('      locale,', (ROOT / 'preview/main.ts').read_text())
        self.assertIn('UNICODE LICENSE V3', (ROOT / 'locale/NOTICE.txt').read_text())

if __name__ == '__main__':
    unittest.main()
