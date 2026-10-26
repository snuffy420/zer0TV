"""Build compact, ID-matched fixtures for the public US live channelss."""
import gzip
import json
import re
import time
import urllib.request
from pathlib import Path
from build_epg import convert, normalized_id

ROOT = Path(__file__).resolve().parents[1]


def build_provider(provider):
    with urllib.request.urlopen(provider["playlistUrl"], timeout=45) as response:
        playlist = response.read().decode("utf-8-sig")
    ids = {normalized_id(value) for value in re.findall(r'tvg-id="([^"]+)"', playlist)}
    if not ids:
        raise ValueError("Playlist contains no station IDs")
    now = int(time.time())
    with urllib.request.urlopen(provider["epgUrl"], timeout=90) as response:
        stream = gzip.GzipFile(fileobj=response) if provider["epgUrl"].endswith(".gz") else response
        full = convert(stream, "us", now=now, supported=(ids, set()))
    if not full["channels"]:
        raise ValueError("No matching guide channels")

    result = None
    payload = None
    # Keep every matching station; reduce text/future depth rather than drop stations.
    for per_channel, description_limit in [(48, 120), (32, 80), (24, 0)]:
        channels = []
        for entry in full["channels"]:
            programmes = []
            for p in entry["programmes"]:
                if p["stop"] > now - 900 and p["start"] < now + 86400:
                    programmes.append({"start": p["start"], "stop": p["stop"], "title": p["title"][:160], "description": p["description"][:description_limit]})
            if programmes:
                channels.append({"id": entry["id"], "name": entry["name"], "programmes": programmes[:per_channel]})
        result = {"version": 1, "provider": provider["id"], "country": "us", "generated": now, "source": provider["epgUrl"], "channels": channels}
        payload = json.dumps(result, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        if len(payload) <= 4_000_000:
            break
    if len(payload) > 4_000_000:
        raise ValueError("Fixture exceeds 4 MB input budget")
    destination = ROOT / "config/provider-guides" / provider["id"]
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "us.json").write_bytes(payload)
    fixture_ids = {normalized_id(entry["id"]) for entry in result["channels"]}
    stats = {"provider": provider["id"], "playlist_channels": len(ids), "guide_channels": len(fixture_ids), "exact_id_matches": len(ids & fixture_ids), "fixture_bytes": len(payload), "programme_cap_per_station": per_channel}
    print(json.dumps(stats), flush=True)
    return stats


if __name__ == "__main__":
    providers = json.loads((ROOT / "config/providers.json").read_text(encoding="utf-8"))
    stats = [build_provider(provider) for provider in providers]
    output = ROOT / "docs/provider-validation.json"
    output.write_text(json.dumps({"generated": int(time.time()), "sources": stats}, indent=2), encoding="utf-8")
