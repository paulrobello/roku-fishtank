#!/usr/bin/env python3
"""Build bundled Roku XLIFF catalogs from reviewed UTF-8 source tables.

Country translations are frozen Intl.DisplayNames (ICU/CLDR) output plus explicit
names for Natural Earth territories absent from ISO. No network access required.
"""
from pathlib import Path
import json
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LOCALES = {'en_US': None, 'en_GB': None, 'en_AU': None,
           'fr_CA': 0, 'es_ES': 1, 'es_MX': 1, 'de_DE': 2, 'it_IT': 3, 'pt_BR': 4}

def build():
    table = {}
    for line in (HERE / 'translations.tsv').read_text().splitlines():
        cells = line.split('\t')
        if len(cells) != 6 or not all(cells):
            raise ValueError(f'Invalid translation row: {cells[0]}')
        if cells[0] in table:
            raise ValueError(f'Duplicate source: {cells[0]}')
        table[cells[0]] = cells[1:]
    table.update(json.loads((HERE / 'countries.json').read_text()))
    for locale, column in LOCALES.items():
        xliff = ET.Element('xliff', {'version': '1.2', 'xmlns': 'urn:oasis:names:tc:xliff:document:1.2'})
        file = ET.SubElement(xliff, 'file', {'source-language': 'en-US', 'target-language': locale.replace('_', '-'), 'datatype': 'plaintext', 'original': 'Reef Tank'})
        body = ET.SubElement(file, 'body')
        for i, source in enumerate(sorted(table)):
            target = source if column is None else table[source][column]
            # Correct a Natural Earth source typo in the displayed name only.
            if column is None and source == 'Necw Zealand':
                target = 'New Zealand'
            unit = ET.SubElement(body, 'trans-unit', {'id': str(i)})
            ET.SubElement(unit, 'source').text = source
            ET.SubElement(unit, 'target').text = target
        ET.indent(xliff, space=' ')
        path = ROOT / 'locale' / locale / 'translations.xml'
        path.parent.mkdir(parents=True, exist_ok=True)
        ET.ElementTree(xliff).write(path, encoding='utf-8', xml_declaration=True)
        with path.open('ab') as f:
            f.write(b'\n')
        print(f'{locale}: {len(table)} strings')

if __name__ == '__main__':
    build()
