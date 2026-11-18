"""Every country guide from every free XMLTV feed we know of.

Feeds (each downloaded and read once per run, however many countries use it):
  * iptv-epg.org country feeds   epg/sources.json (kept up to date by discovery)
  * epgshare01 country feeds      found on its index page each run (UK1 -> gb ...)
  * epg.pw country feeds          found on its index page each run
  * service feeds (Plex, Peacock, Whale TV+, Rakuten, AMC, TBN+...) for every country
  * epg/extra-sources.json        anything else, by country, or "*" for all

For each country the IPTV-org country playlist (plus Free-TV) is matched to
the feeds in order; a later feed only adds channels the earlier ones missed.
"""
import concurrent.futures
import gzip
import json
import re
import tempfile
import threading
import time
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from epg_match import Matcher, playlist_entries
from guide_http import urlopen

EPGSHARE = "https://epgshare01.online/epgshare01/"
EPGPW = "https://epg.pw/xmltv.html"
# epgshare01 service feeds: tried for every country.
EPGSHARE_SERVICES = ["ALJAZEERA1", "AMCCHANNELS1", "ASIANTELEVISION1", "BEIN1", "DELUXEMUSIC1", "DIRECTVSPORTS1",
                     "DISTROTV1", "DRAFTKINGS1", "FANDUEL1", "MUSICBOX1", "PEACOCK1", "PLEX1", "RAKUTEN1", "RALLY_TV1",
                     "SPORTKLUB1", "TBNPLUS1", "VOA1", "WHALETVPLUS1"]
# epgshare01 feeds for one country that aren't named by its code.
EPGSHARE_NAMED = {"US_LOCALS1": "us", "US_SPORTS1": "us", "UK1": "gb"}
# Never used: everything at once (huge), placeholders, radio.
EPGSHARE_SKIP = {"ALL_SOURCES1", "DUMMY_CHANNELS", "AUDACY1"}
WINDOW_BACK, WINDOW_AHEAD = 3600, 64800
AGENT = {"User-Agent": "zer0TV-Guide/2.0"}


def http_text(url, timeout=45):
    with urlopen(urllib.request.Request(url, headers=AGENT), timeout=timeout) as response:
        return response.read().decode("utf-8", "replace")


def epgshare_feeds():
    """{country: [urls]} and the service feed urls, from epgshare01's index."""
    names = sorted(set(re.findall(r"epg_ripper_([A-Z0-9_]+)\.xml\.gz", http_text(EPGSHARE))))
    by_country, services = {}, []
    for name in names:
        url = f"{EPGSHARE}epg_ripper_{name}.xml.gz"
        if name in EPGSHARE_SKIP:
            continue
        if name in EPGSHARE_SERVICES:
            services.append(url)
        elif name in EPGSHARE_NAMED:
            by_country.setdefault(EPGSHARE_NAMED[name], []).append(url)
        elif re.fullmatch(r"[A-Z]{2}\d*", name):
            by_country.setdefault(name[:2].lower(), []).append(url)
    return by_country, services


def epgpw_feeds():
    names = sorted(set(re.findall(r"epg_([A-Z]{2})\.xml\.gz", http_text(EPGPW))))
    return {("gb" if n == "GB" else n.lower()): [f"https://epg.pw/xmltv/epg_{n}.xml.gz"] for n in names}


def feed_plan(sources, extras):
    """{country: [feed urls in order]} for every country any feed covers."""
    plan = {}

    def add(country, urls):
        if not re.fullmatch("[a-z]{2}", country):
            return
        for url in urls:
            if url not in plan.setdefault(country, []):
                plan[country].append(url)

    for country, url in sources.items():
        add(country, [url])
    services = []
    try:
        share, services = epgshare_feeds()
        for country, urls in share.items():
            add(country, urls)
    except Exception as exc:
        print("epgshare01 index unavailable:", exc, flush=True)
    try:
        for country, urls in epgpw_feeds().items():
            add(country, urls)
    except Exception as exc:
        print("epg.pw index unavailable:", exc, flush=True)
    for country, urls in extras.items():
        if country != "*":
            add(country, urls)
    services = services + [u for u in extras.get("*", []) if u not in services]
    for country in plan:
        add(country, services)
    return plan, services


class FeedStore:
    """Downloads each feed once and reads it into {names, programmes} (only
    programmes inside the window are kept)."""

    def __init__(self, folder, now):
        self.folder = Path(folder)
        self.now = now
        self.files = {}
        self.loaded = {}
        self.lock = threading.Lock()

    def download(self, url):
        path = self.folder / re.sub(r"[^A-Za-z0-9._-]", "_", url.split("//", 1)[-1])
        try:
            with urlopen(urllib.request.Request(url, headers=AGENT), timeout=180) as response, open(path, "wb") as out:
                while True:
                    chunk = response.read(1 << 20)
                    if not chunk:
                        break
                    out.write(chunk)
            self.files[url] = path
        except Exception as exc:
            print(f"feed unavailable ({url}): {exc}", flush=True)
            self.files[url] = None

    def download_all(self, urls, workers=8):
        with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
            list(pool.map(self.download, [u for u in urls if u not in self.files]))

    def read(self, url):
        path = self.files.get(url)
        if path is None:
            return None
        names, programmes = {}, {}
        try:
            with open(path, "rb") as raw:
                stream = gzip.GzipFile(fileobj=raw) if raw.read(2) == b"\x1f\x8b" else raw
                raw.seek(0)
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
                        channel_id = element.get("channel", "")
                        try:
                            start = xmltv_time(element.get("start", ""))
                            stop = xmltv_time(element.get("stop", ""))
                        except ValueError:
                            root.remove(element)
                            continue
                        if stop > self.now - WINDOW_BACK and start < self.now + WINDOW_AHEAD and stop > start:
                            programmes.setdefault(channel_id, []).append({
                                "start": start, "stop": stop,
                                "title": (element.findtext("title") or "Untitled programme")[:160],
                                "description": (element.findtext("desc") or "")[:200],
                            })
                        root.remove(element)
        except Exception as exc:
            print(f"feed unreadable ({url}): {exc}", flush=True)
            if not names:
                return None
        return {"names": names, "programmes": programmes}

    def get(self, url, keep):
        """A read feed; service feeds (keep=True) stay in memory for every country."""
        with self.lock:
            if url in self.loaded:
                return self.loaded[url]
        feed = self.read(url)
        if keep:
            with self.lock:
                self.loaded[url] = feed
        return feed


def xmltv_time(value):
    match = re.fullmatch(r"(\d{14})(?:\s*([+-]\d{4}|Z))?", value.strip())
    if not match:
        raise ValueError(value)
    zone = (match[2] or "+0000").replace("Z", "+0000")
    stamp = time.strptime(match[1], "%Y%m%d%H%M%S")
    import calendar
    seconds = calendar.timegm(stamp)
    sign = 1 if zone[0] == "+" else -1
    return seconds - sign * (int(zone[1:3]) * 3600 + int(zone[3:5]) * 60)


def matched_channels(feed, country, matcher):
    """The feed's channels for this country's playlist, with the ids/names served."""
    kept = matcher.assign(feed["names"], country)
    channels = []
    for feed_id, served in kept.items():
        programmes = sorted(feed["programmes"].get(feed_id, []), key=lambda p: (p["start"], p["stop"]))
        seen, unique = set(), []
        for p in programmes:
            key = (p["start"], p["stop"], p["title"])
            if key not in seen:
                unique.append(p)
                seen.add(key)
        if not unique:
            continue
        entry = {"id": feed_id, "name": (feed["names"].get(feed_id) or [feed_id])[0], "programmes": unique[:80]}
        if served["ids"]:
            entry["ids"] = served["ids"]
        if served["names"]:
            entry["names"] = served["names"]
        channels.append(entry)
    return channels


def merge(channels, extra):
    """Add the extra feed's channels for playlist ids/names not served yet."""
    served = set()
    for entry in channels:
        served.update(entry.get("ids", []))
        served.update("name:" + n for n in entry.get("names", []))
    for entry in extra:
        ids = [i for i in entry.get("ids", []) if i not in served]
        names = [n for n in entry.get("names", []) if "name:" + n not in served]
        if not ids and not names:
            continue
        entry = {k: v for k, v in entry.items() if k not in ("ids", "names")}
        if ids:
            entry["ids"] = ids
        if names:
            entry["names"] = names
        served.update(ids)
        served.update("name:" + n for n in names)
        channels.append(entry)
    return channels


def build_countries(sources, extras, destination, country_playlist, free_tv_playlist, compact_payload, only=None):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    now = int(time.time())
    plan, services = feed_plan(sources, extras)
    if only:
        plan = {c: u for c, u in plan.items() if c in only}
    status = []
    with tempfile.TemporaryDirectory() as folder:
        store = FeedStore(folder, now)
        started = time.time()
        store.download_all(sorted({u for urls in plan.values() for u in urls}))
        print(f"downloaded {len(store.files)} feeds in {time.time() - started:.0f}s", flush=True)
        free_tv = free_tv_playlist()
        for country in sorted(plan):
            began = time.time()
            try:
                try:
                    playlist = country_playlist(country)
                except Exception:
                    playlist = free_tv  # no IPTV-org list for this country: Free-TV only
                matcher = Matcher(playlist_entries(playlist))
                channels = []
                used = []
                for url in plan[country]:
                    feed = store.get(url, keep=url in services)
                    if feed is None:
                        continue
                    before = len(channels)
                    channels = merge(channels, matched_channels(feed, country, matcher))
                    if len(channels) > before:
                        used.append(url)
                    if url not in services:
                        feed = None  # a country's own feed is only needed once
                if not channels:
                    print(f"{country}: no current matching listings; retaining previous file", flush=True)
                    status.append({"country": country, "status": "no-matching-listings", "channels": 0})
                    continue
                result = {"version": 2, "country": country, "generated": now,
                          "source": "XMLTV: " + ", ".join(u.split("/")[2] for u in used), "channels": channels}
                payload = compact_payload(result)
                temp = destination / f"{country}.json.tmp"
                temp.write_bytes(payload)
                temp.replace(destination / f"{country}.json")
                served = sum(len(c.get("ids", [])) + len(c.get("names", [])) for c in channels)
                print(f"{country}: {len(channels)} guide channels for {served} playlist channels, "
                      f"{len(payload):,} bytes, {len(used)} feeds, {time.time() - began:.0f}s", flush=True)
                status.append({"country": country, "status": "ok", "channels": len(channels), "served": served,
                               "bytes": len(payload), "feeds": used})
            except Exception as exc:
                print(f"{country}: FAILED: {exc}", flush=True)
                status.append({"country": country, "status": "failed", "error": str(exc)})
    (destination / "country-status.json").write_text(json.dumps({"generated": now, "feeds": status}, indent=2), encoding="utf-8")
    return status
