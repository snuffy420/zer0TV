"""Convert country XMLTV feeds to compact, Roku-friendly JSON (standard library only)."""
import argparse
import datetime as dt
import gzip
import functools
import json
import re
import time
import urllib.request
import xml.etree.ElementTree as ET
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
    with urllib.request.urlopen("https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8", timeout=45) as response:
        return response.read().decode("utf-8-sig")


def supported_channels(country):
    playlist_country = "uk" if country == "gb" else country
    url = f"https://iptv-org.github.io/iptv/countries/{playlist_country}.m3u"
    with urllib.request.urlopen(url, timeout=45) as response:
        playlist = response.read().decode("utf-8-sig")
    playlist += "\n" + free_tv_playlist()
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
                    "title": element.findtext("title", "Untitled programme"),
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


def build(sources_path, destination):
    sources = json.loads(Path(sources_path).read_text(encoding="utf-8"))
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    failures = []
    for country, url in sources.items():
        if not re.fullmatch("[a-z]{2}", country):
            raise ValueError(f"Use a lowercase ISO country code: {country}")
        try:
            supported = supported_channels(country)
            request = urllib.request.Request(url, headers={"User-Agent": "zer0TV-Guide/1.5"})
            with urllib.request.urlopen(request, timeout=90) as response:
                stream = gzip.GzipFile(fileobj=response) if url.endswith(".gz") else response
                result = convert(stream, country, supported=supported)
            if not result["channels"]:
                raise ValueError("Feed has no current listings; preserving previous output")
            payload = json.dumps(result, ensure_ascii=False, separators=(",", ":"))
            if len(payload.encode("utf-8")) > 4_000_000:
                raise ValueError("JSON exceeds the Roku 4 MB feed budget; reduce the schedule horizon")
            temp = destination / f"{country}.json.tmp"
            temp.write_text(payload, encoding="utf-8")
            temp.replace(destination / f"{country}.json")
            print(f"{country}: {len(result['channels'])} channels, {len(payload.encode('utf-8')):,} bytes")
        except Exception as exc:
            failures.append(country)
            print(f"{country}: FAILED: {exc}")
    if failures:
        raise SystemExit("Country feeds failed: " + ", ".join(failures))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", default="epg/sources.json")
    parser.add_argument("--output", default="epg/data")
    args = parser.parse_args()
    build(args.sources, args.output)
