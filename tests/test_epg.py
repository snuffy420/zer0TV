import io
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_epg import convert, timestamp


class GuideTests(unittest.TestCase):
    def test_offsets_and_dst_transition(self):
        self.assertEqual(timestamp("20261025013000 +0100"), timestamp("20261025003000 +0000"))
        self.assertEqual(timestamp("20261025013000 -0400"), timestamp("20261025053000 +0000"))
        self.assertEqual(timestamp("20261025013000"), timestamp("20261025013000 +0000"))
        with self.assertRaises(ValueError):
            timestamp("not-a-date")

    def test_feed_keeps_real_listings_drops_old_invalid_and_duplicates(self):
        xml = b'''<tv>
          <channel id="News.us"><display-name>News &amp; more</display-name></channel>
          <programme channel="News.us" start="20261025010000 +0000" stop="20261025020000 +0000"><title>Old</title></programme>
          <programme channel="News.us" start="20261025180000 +0000" stop="20261025190000 +0000"><title>Later</title></programme>
          <programme channel="News.us" start="20261025170000 +0000" stop="20261025180000 +0000"><title>Live &amp; Local</title><desc>Description</desc></programme>
          <programme channel="News.us" start="20261025170000 +0000" stop="20261025180000 +0000"><title>Live &amp; Local</title></programme>
          <programme channel="News.us" start="broken" stop="broken"><title>Invalid</title></programme>
          <programme channel="News.us" start="20261025190000 +0000" stop="20261025180000 +0000"><title>Reversed</title></programme>
        </tv>'''
        result = convert(io.BytesIO(xml), "us", timestamp("20261025173000 +0000"))
        self.assertEqual(len(result["channels"]), 1)
        channel = result["channels"][0]
        self.assertEqual(channel["name"], "News & more")
        self.assertEqual([p["title"] for p in channel["programmes"]], ["Live & Local", "Later"])
        self.assertEqual(json.loads(json.dumps(result)), result)


if __name__ == "__main__":
    unittest.main()
