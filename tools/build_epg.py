"""Convert country XMLTV feeds to compact, Roku-friendly JSON (standard library only)."""
import argparse
import datetime as dt
import gzip
import functools
import json
import re
import time
import urllib.request
from guide_http import urlopen
from epg_match import Matcher, playlist_entries
import xml.etree.ElementTree as ET
import concurrent.futures
from pathlib import Path


def timestamp(value):
    value = value.strip()
    # XMLTV permits an omitted offset; the XMLTV default is UTC.
    match = re.fullmatch(r"(\d{14})(?:\s+([+-]\d{4}|Z))?", value)
    if not match:
        raise ValueError(f"Invalid XMLTV timestamp: {value}")
    zone = match[2] or "+0000"
    return int(dt.datetime.strptime(match[1] + zone.replace("Z", "+0000"), "%Y%m%d%H%M%S%z").timestamp())


def normalized_name(value):
    value = re.sub(r"^[A-Z]{2}\s*-\s*", "", value)
    value = re.sub(r"\s*\([0-9]+p\).*$", "", value, flags=re.I)
    return re.sub("[^a-z0-9]", "", value.lower())


def normalized_id(value):
    return re.sub(r"@(SD|HD|FHD|UHD|4K|8K|[0-9]+p)$", "", value.lower(), flags=re.I)


@functools.lru_cache(maxsize=1)
def free_tv_playlist():
    with urlopen("https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8", timeout=45) as response:
        return response.read().decode("utf-8-sig")


def country_playlist(country):
    playlist_country = "uk" if country == "gb" else country
    url = f"https://iptv-org.github.io/iptv/countries/{playlist_country}.m3u"
    with urlopen(url, timeout=45) as response:
        playlist = response.read().decode("utf-8-sig")
    return playlist + "\n" + free_tv_playlist()


def supported_channels(country):
    playlist = country_playlist(country)
    ids, names = set(), set()
    for line in playlist.splitlines():
        if not line.startswith("#EXTINF:"):
            continue
        quoted = False
        for index, char in enumerate(line):
            if char == '"':
                quoted = not quoted
            if char == "," and not quoted:
                name = normalized_name(line[index + 1:])
                if name:
                    names.add(name)
                break
        match = re.search(r'tvg-id="([^"]+)"', line)
        if match:
            ids.add(normalized_id(match[1]))
    if not ids and not names:
        raise ValueError("No supported channels found in upstream playlists")
    return ids, names


def convert_matched(stream, country, matcher, now=None):
    """A country feed for the IPTV-org / Free-TV playlists: each kept feed
    channel lists the playlist ids ("ids") and names ("names") it serves, so
    the Roku finds listings under the playlist's own tvg-id. Listings from an
    hour ago to 18 hours ahead (the feed is rebuilt every 6 hours)."""
    now = int(time.time()) if now is None else now
    names = {}
    kept = None
    channels = {}
    context = ET.iterparse(stream, events=("start", "end"))
    _, root = next(context)
    for event, element in context:
        if event != "end":
            continue
        if element.tag == "channel":
            channel_id = element.get("id", "")
            if channel_id:
                names[channel_id] = [n.text or "" for n in element.findall("display-name")]
            root.remove(element)
        elif element.tag == "programme":
            if kept is None:
                kept = matcher.assign(names, country)
                for feed_id, served in kept.items():
                    display = (names.get(feed_id) or [feed_id])[0]
                    channels[feed_id] = {"id": feed_id, "name": display, "ids": served["ids"], "names": served["names"], "programmes": []}
            channel_id = element.get("channel", "")
            if channel_id in channels:
                try:
                    start = timestamp(element.get("start", ""))
                    stop = timestamp(element.get("stop", ""))
                except ValueError:
                    root.remove(element)
                    continue
                if stop > now - 3600 and start < now + 64800 and stop > start:
                    channels[channel_id]["programmes"].append({
                        "start": start, "stop": stop,
                        "title": element.findtext("title", "Untitled programme")[:160],
                        "description": element.findtext("desc", "")[:200],
                    })
            root.remove(element)
    output = []
    for entry in channels.values():
        entry["programmes"].sort(key=lambda p: (p["start"], p["stop"]))
        seen, programmes = set(), []
        for p in entry["programmes"]:
            key = (p["start"], p["stop"], p["title"])
            if key not in seen:
                programmes.append(p)
                seen.add(key)
        entry["programmes"] = programmes[:80]
        if not entry["ids"]:
            del entry["ids"]
        if not entry["names"]:
            del entry["names"]
        if entry["programmes"]:
            output.append(entry)
    return {"version": 2, "country": country, "generated": now, "source": "XMLTV; see epg/sources.json", "channels": output}


def convert(stream, country, now=None, supported=None):
    now = int(time.time()) if now is None else now
    channels = {}
    # Remove processed elements from the root, not only their contents, to bound memory.
    context = ET.iterparse(stream, events=("start", "end"))
    _, root = next(context)
    for event, element in context:
        if event != "end":
            continue
        if element.tag == "channel":
            channel_id = element.get("id", "")
            names = [n.text or "" for n in element.findall("display-name")]
            included = supported is None or normalized_id(channel_id) in supported[0] or any(normalized_name(n) in supported[1] for n in names)
            if channel_id and included:
                channels[channel_id] = {
                    "id": channel_id,
                    "name": element.findtext("display-name", channel_id),
                    "programmes": [],
                }
            root.remove(element)
        elif element.tag == "programme":
            channel_id = element.get("channel", "")
            try:
                start = timestamp(element.get("start", ""))
                stop = timestamp(element.get("stop", ""))
            except ValueError:
                root.remove(element)
                continue
            if (supported is None or channel_id in channels) and stop > now - 10800 and start < now + 97200 and stop > start:
                entry = channels.setdefault(channel_id, {"id": channel_id, "name": channel_id, "programmes": []})
                entry["programmes"].append({
                    "start": start, "stop": stop,
                    "title": element.findtext("title", "Untitled programme")[:160],
                    "description": element.findtext("desc", "")[:240],
                })
            root.remove(element)
    output = []
    for entry in channels.values():
        entry["programmes"].sort(key=lambda p: (p["start"], p["stop"]))
        # Keep each broadcast once, even if an upstream feed repeats it.
        seen = set()
        programmes = []
        for p in entry["programmes"]:
            key = (p["start"], p["stop"], p["title"])
            if key not in seen:
                programmes.append(p)
                seen.add(key)
        entry["programmes"] = programmes[:160]
        if entry["programmes"]:
            output.append(entry)
    return {"version": 1, "country": country, "generated": now, "source": "XMLTV; see epg/sources.json", "channels": output}


def compact_payload(result):
    for cap, description in [(160, 240), (64, 120), (32, 80), (16, 0), (8, 0)]:
        candidate = {**result, "channels": [{**entry, "programmes": [{**p, "description": p.get("description", "")[:description]} for p in entry["programmes"][:cap]]} for entry in result["channels"]]}
        payload = json.dumps(candidate, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        if len(payload) <= 3_800_000:
            return payload
    raise ValueError("Guide exceeds the 4 MB Roku input budget after compaction")


def merge_feeds(result, extra):
    """Add an extra feed's channels for playlist ids and names the result
    doesn't serve yet (the first feed wins where both have a channel)."""
    served = set()
    for entry in result["channels"]:
        served.update(entry.get("ids", []))
        served.update("name:" + n for n in entry.get("names", []))
    for entry in extra["channels"]:
        ids = [i for i in entry.get("ids", []) if i not in served]
        names = [n for n in entry.get("names", []) if "name:" + n not in served]
        if not ids and not names:
            continue
        entry = dict(entry)
        entry.pop("ids", None)
        entry.pop("names", None)
        if ids:
            entry["ids"] = ids
        if names:
            entry["names"] = names
        served.update(ids)
        served.update("name:" + n for n in names)
        result["channels"].append(entry)
    return result


def build(sources_path, destination, workers=4):
    sources = json.loads(Path(sources_path).read_text(encoding="utf-8"))
    # Extra feeds per country (kept apart: discovery rewrites sources.json).
    extra_path = Path(sources_path).with_name("extra-sources.json")
    extras = json.loads(extra_path.read_text(encoding="utf-8")) if extra_path.exists() else {}
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    failures = []
    free_tv_playlist()  # one download shared by country workers

    def one(pair):
        country, url = pair
        if not re.fullmatch("[a-z]{2}", country):
            raise ValueError(f"Use a lowercase ISO country code: {country}")
        try:
            matcher = Matcher(playlist_entries(country_playlist(country)))
            result = None
            # The main feed, then any extra feeds for the channels it misses.
            feeds = [url] + extras.get(country, [])
            # epg.pw has a guide for most countries: tried for every one.
            pw = f"https://epg.pw/xmltv/epg_{country.upper()}.xml.gz"
            if pw not in feeds:
                feeds.insert(1, pw)
            for index, feed_url in enumerate(feeds):
                try:
                    request = urllib.request.Request(feed_url, headers={"User-Agent": "zer0TV-Guide/1.5"})
                    with urlopen(request, timeout=90) as response:
                        stream = gzip.GzipFile(fileobj=response) if feed_url.endswith(".gz") else response
                        part = convert_matched(stream, country, matcher)
                except Exception as exc:
                    if index == 0:
                        raise
                    print(f"{country}: extra feed skipped ({feed_url}): {exc}", flush=True)
                    continue
                result = part if result is None else merge_feeds(result, part)
            if not result["channels"]:
                print(f"{country}: no current matching listings; retaining previous file and retrying next run", flush=True)
                return {"country": country, "status": "no-matching-listings", "channels": 0}
            payload = compact_payload(result)
            temp = destination / f"{country}.json.tmp"
            temp.write_bytes(payload)
            temp.replace(destination / f"{country}.json")
            print(f"{country}: {len(result['channels'])} channels, {len(payload):,} bytes", flush=True)
            return {"country": country, "status": "ok", "channels": len(result["channels"]), "bytes": len(payload)}
        except Exception as exc:
            print(f"{country}: FAILED: {exc}", flush=True)
            return {"country": country, "status": "failed", "error": str(exc)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        status = list(pool.map(one, sources.items()))
    (destination / "country-status.json").write_text(json.dumps({"generated": int(time.time()), "feeds": status}, indent=2), encoding="utf-8")
    failures = [entry["country"] for entry in status if entry["status"] == "failed"]
    if failures:
        raise SystemExit("Country feeds failed: " + ", ".join(failures))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", default="epg/sources.json")
    parser.add_argument("--output", default="epg/data")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    build(args.sources, args.output, max(1, min(args.workers, 6)))
