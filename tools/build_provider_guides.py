"""Build compact, ID-matched fixtures for the public US live channelss."""
import gzip
import argparse
import concurrent.futures
import json
import re
import time
import urllib.request
from guide_http import urlopen
from pathlib import Path
from build_epg import convert, normalized_id

ROOT = Path(__file__).resolve().parents[1]


def build_provider(provider, destination=None):
    code = provider.get("code", "us").lower()
    destination = Path(destination) if destination else ROOT / "epg/data/providers"
    with urlopen(provider["playlistUrl"], timeout=45) as response:
        playlist = response.read().decode("utf-8-sig")
    ids = {normalized_id(value) for value in re.findall(r'tvg-id="([^"]+)"', playlist)}
    if not ids:
        raise ValueError("Playlist contains no station IDs")
    now = int(time.time())
    with urlopen(provider["epgUrl"], timeout=90) as response:
        stream = gzip.GzipFile(fileobj=response) if provider["epgUrl"].endswith(".gz") else response
        full = convert(stream, code, now=now, supported=(ids, set()))
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
        result = {"version": 1, "provider": provider["id"], "country": code, "generated": now, "source": provider["epgUrl"], "channels": channels}
        payload = json.dumps(result, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        if len(payload) <= 4_000_000:
            break
    if len(payload) > 4_000_000:
        raise ValueError("Fixture exceeds 4 MB input budget")
    destination = destination / provider["id"]
    destination.mkdir(parents=True, exist_ok=True)
    temp = destination / (code + ".json.tmp")
    temp.write_bytes(payload)
    temp.replace(destination / (code + ".json"))
    fixture_ids = {normalized_id(entry["id"]) for entry in result["channels"]}
    stats = {"provider": provider["id"], "country": code, "playlist_channels": len(ids), "guide_channels": len(fixture_ids), "exact_id_matches": len(ids & fixture_ids), "fixture_bytes": len(payload), "programme_cap_per_station": per_channel}
    print(json.dumps(stats), flush=True)
    return stats


def build_all(providers_path, output, workers=4):
    providers = json.loads(Path(providers_path).read_text(encoding="utf-8"))
    jobs = [{**provider, **country} for provider in providers for country in provider["countries"]]
    def one(provider):
        try:
            return {**build_provider(provider, output), "status": "ok"}
        except Exception as error:
            return {"provider": provider["id"], "country": provider.get("code", "us").lower(), "status": "failed", "error": str(error)}
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        status = list(pool.map(one, jobs))
    Path(output).mkdir(parents=True, exist_ok=True)
    (Path(output) / "provider-status.json").write_text(json.dumps({"generated": int(time.time()), "feeds": status}, indent=2), encoding="utf-8")
    failures = [entry for entry in status if entry["status"] != "ok"]
    if failures:
        raise RuntimeError("Provider feeds unavailable: " + ", ".join(entry["provider"] + "/" + entry["country"] for entry in failures))
    return status


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--providers", default="config/providers.json")
    parser.add_argument("--output", default="epg/data/providers")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    build_all(args.providers, args.output, max(1, min(args.workers, 6)))
