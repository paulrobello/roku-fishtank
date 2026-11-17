"""Validate the checked-in offline database without network access."""
import json
import hashlib
from codec import ZipDatabase, canonical, decode, encode
import unittest
from pathlib import Path

DATA = Path(__file__).resolve().parents[2] / "config/location"


class LocationDataTest(unittest.TestCase):
    def test_zip_records(self):
        data = (DATA / "us-zips.bin").read_bytes()
        fixture = json.loads((Path(__file__).parent / "data_hashes.json").read_text())
        records = decode(data)
        self.assertEqual(len(records), fixture["zip_count"])
        self.assertEqual(hashlib.sha256(canonical(records)).hexdigest(), fixture["zip_legacy_sha256"])
        self.assertEqual(hashlib.sha256(data).hexdigest(), fixture["zip_binary_sha256"])
        self.assertEqual(encode(records), data)
        database = ZipDatabase(data)
        self.assertEqual(len(database.first), 264)
        expected = {row[0]: row for row in records}
        # All 100,000 possible five-digit inputs: exact coordinates or no match.
        for code in range(100000):
            self.assertEqual(database.lookup(f"{code:05}"), expected.get(code), code)
        self.assertIsNotNone(database.lookup("00601"))
        self.assertIsNotNone(database.lookup("95776"))
        for invalid in ("601", "00000", "123456", "abcde", "１２３４５", -1, 100000, None):
            self.assertIsNone(database.lookup(invalid))

    def test_codec_edges(self):
        for count in (0, 1, 127, 128, 129, 256, 257):
            rows = [(i+1, 18000 if i % 2 else 0, 0 if i % 2 else 36000) for i in range(count)]
            self.assertEqual(decode(encode(rows)), rows)
        for data in (b"", b"BAD!", b"ZP01", encode([(1, 0, 0)])[:-1]):
            with self.assertRaises(ValueError):
                decode(data)
        with self.assertRaises(ValueError):
            encode([(1, 0, 0), (1, 0, 0)])

    def test_country_cities(self):
        countries = json.loads((DATA / "countries.json").read_text())
        self.assertEqual(len(countries), 228)
        self.assertEqual(countries, sorted(countries))
        self.assertIn("United States of America", [row[0] for row in countries])
        total = 0
        for country, key in countries:
            self.assertTrue(country)
            rows = json.loads((DATA / f"cities-{key}.json").read_text())
            self.assertTrue(rows)
            self.assertEqual(rows, sorted(rows))
            total += len(rows)
            for name, lat, lon in rows:
                self.assertTrue(name)
                self.assertIsInstance(lat, int)
                self.assertTrue(-9000 <= lat <= 9000)
                self.assertIsInstance(lon, int)
                self.assertTrue(-18000 <= lon <= 18000)
        self.assertEqual(total, 7342)
        fixture = json.loads((Path(__file__).parent / "data_hashes.json").read_text())
        canonical_cities = [[p.name, json.loads(p.read_text())] for p in sorted(DATA.glob("cities-*.json"))]
        digest = hashlib.sha256(json.dumps(canonical_cities, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()
        self.assertEqual(digest, fixture["city_canonical_sha256"])


if __name__ == "__main__":
    unittest.main()
