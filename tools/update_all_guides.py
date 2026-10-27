"""Refresh every public guide and Free-TV theme group, preserving last good files on failure."""
import argparse
import json
import re
import time
from pathlib import Path
from build_epg import build, compact_payload, free_tv_playlist, normalized_id, normalized_name
from build_provider_guides import build_all
from discover_epg_sources import discover


def build_groups(root):
    mapping = json.loads((root / "config/freetv-regions.json").read_text(encoding="utf-8"))
    wanted = {}
    for line in free_tv_playlist().splitlines():
        if not line.startswith("#EXTINF:"):
            continue
        group = re.search(r'group-title="([^"]+)"', line)
        code = mapping.get(group[1], "") if group else ""
        if not code.startswith("group-"):
            continue
        ids, names = wanted.setdefault(code, (set(), set()))
        station = re.search(r'tvg-id="([^"]+)"', line)
        if station and station[1]:
            ids.add(normalized_id(station[1]))
        quoted = False
        for i, char in enumerate(line):
            if char == '"':
                quoted = not quoted
            if char == "," and not quoted:
                names.add(normalized_name(line[i+1:]))
                break
    stations = {code: {} for code in wanted}
    files = sorted((root / "epg/data").glob("??.json")) + sorted((root / "epg/data/providers").glob("*/??.json"))
    now = int(time.time())
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        if now - data.get("generated", 0) > 86400:
            continue
        for entry in data.get("channels", []):
            for code, (ids, names) in wanted.items():
                if normalized_id(entry["id"]) in ids or normalized_name(entry["name"]) in names:
                    stations[code].setdefault(entry["id"], entry)
    status = []
    for code, entries in stations.items():
        if not entries:
            status.append({"group": code, "status": "no-public-listings"})
            continue
        payload = compact_payload({"version": 1, "country": code, "generated": now, "source": "Matching public country/provider guides", "channels": list(entries.values())})
        path = root / "epg/data" / (code + ".json")
        path.write_bytes(payload)
        status.append({"group": code, "status": "ok", "channels": len(entries)})
    return status


def update(root, workers):
    failures = []
    try:
        discover(root)
    except Exception as error:
        failures.append("Discovery: " + str(error))
        print("Keeping existing discovery manifests:", error, flush=True)
    for label, action in [("Countries", lambda: build(root / "epg/sources.json", root / "epg/data", workers)),
                          ("Providers", lambda: build_all(root / "epg/providers.json", root / "epg/data/providers", workers))]:
        try:
            action()
        except (Exception, SystemExit) as error:
            failures.append(label + ": " + str(error))
    groups = build_groups(root)
    report = {"generated": int(time.time()), "failures": failures, "groups": groups}
    (root / "epg/data/update-status.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    if failures:
        raise SystemExit("Some feeds failed; successful updates were saved. " + " | ".join(failures))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    update(args.root, max(1, min(args.workers, 6)))
