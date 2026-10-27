import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class MoviePanelTests(unittest.TestCase):
    def test_details_and_search_keep_header_and_right_panel_visible(self):
        tree = ET.parse(ROOT / "components/MovieUI.xml")
        for panel_id in ("movieDetailPanel", "movieSearchPanel"):
            panel = tree.find(f".//Group[@id='{panel_id}']")
            x, y = map(int, re.findall(r"\d+", panel.get("translation")))
            background = panel.find("Rectangle")
            self.assertGreaterEqual(y, 94)
            self.assertLessEqual(x + int(background.get("width")), 720)
            self.assertLessEqual(y + int(background.get("height")), 680)
            self.assertIsNone(panel.find(".//Label[@id='movieTitle']"))
        self.assertNotIn("KeyboardDialog", (ROOT / "components/MovieUI.brs").read_text())

    def test_private_key_does_not_enter_github_guide_manifest(self):
        for relative in ("epg/sources.json", "epg/providers.json", "config/epg-sources.json"):
            text = (ROOT / relative).read_text()
            self.assertNotIn("cinejoy", text.lower())
            self.assertNotIn("ACCESS_KEY", text)
