"""Focused checks for bundled, read-only development history."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class HistoryTest(unittest.TestCase):
    def test_unreleased_is_not_a_published_version(self):
        rows = json.loads((ROOT / "config/changelog.json").read_text())
        self.assertIsNone(rows[0]["version"])
        self.assertEqual(rows[0]["status"], "unreleased")
        self.assertIn("Unreleased", rows[0]["title"])
        self.assertEqual([r["version"] for r in rows[1:]], ["0.2.2", "0.2.1", "0.1.1"])
        self.assertNotIn("published", [r["status"] for r in rows])

    def test_entries_fit_and_remain_high_level(self):
        rows = json.loads((ROOT / "config/changelog.json").read_text())
        self.assertEqual(len(rows), 4)
        for row in rows:
            self.assertLessEqual(len(row["title"]), 48)
            self.assertIsInstance(row["message"], list)
            self.assertLessEqual(sum(map(len, row["message"])), 320)
            for paragraph in row["message"]:
                self.assertTrue(paragraph.strip())
                self.assertNotIn("\n", paragraph)
            if row["version"]:
                self.assertRegex(row["version"], r"^\d+\.\d+\.\d+$")

    def test_settings_changelog_is_read_only(self):
        source = (ROOT / "components/ReefTankSettings/ReefTankSettings.brs").read_text()
        handler = re.search(r"sub settingsUiChangelogSelected\(.*?end sub", source, re.S).group()
        self.assertNotIn("settingsSave", handler)
        self.assertNotIn("settingsLocationSave", handler)
        self.assertIn('"solarLocation", "digitalClock", "changelog"', source)
        self.assertNotRegex(source, r"(?i)sub\s+onKeyEvent|function\s+onKeyEvent")


if __name__ == "__main__":
    unittest.main()
