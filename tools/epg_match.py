"""Match a country XMLTV feed's channels to the IPTV-org and Free-TV playlists.

Feeds and playlists name the same station differently:

    playlist tvg-id     feed channel id
    ABC.us@KAAL         ABCKAAL.us            (base + sub-feed)
    ABC.us@East         ABCEast_WABC.us       (base + sub-feed, then more)
    AE.us@East          AandENetwork.us       (name "A&E" = "A&E Network")
    CNN.us@SD           CNN.us                (quality tag ignored)

Each playlist channel gets the single best feed channel (exact sub-feed id,
then the plain id, then an id that starts with base + sub-feed, then the same
core name). The output lists, for each feed channel kept, the playlist ids it
serves, so the Roku can look listings up by the playlist's own tvg-id.
"""
import re

QUALITY = re.compile(r"^(sd|hd|fhd|uhd|4k|8k|[0-9]+p)$", re.I)
GENERIC = {"tv", "hd", "network", "channel", "the", "us", "usa", "east", "feed", "live", "television"}
REGIONAL = {"west", "pacific", "mountain", "central"}
# Free streaming services a feed tags its channels with instead of a country.
FAST = {"pluto", "plex", "samsung", "roku", "xumo", "tubi", "stirr", "distro", "localnow", "vizio", "lg", "sling"}


def alnum(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def words(name):
    name = re.sub(r"^[A-Z]{2,3}\s*-\s*", "", name)
    name = re.sub(r"\([^)]*\)|\[[^\]]*\]", " ", name)
    name = name.replace("&", " and ").lower()
    return [w for w in re.split(r"[^a-z0-9]+", name) if w]


def core_name(name):
    return "".join(w for w in words(name) if w not in GENERIC)


def app_name(name):
    """The name the Roku compares (epgName)."""
    name = re.sub(r"^[A-Z]{2}\s*-\s*", "", name)
    name = re.sub(r"\s*\([0-9]+p\).*$", "", name, flags=re.I)
    return re.sub(r"[^a-z0-9]", "", name.lower())


def playlist_key(tvg_id):
    """The id the Roku looks up: lowercase, quality tag dropped (epgId)."""
    return re.sub(r"@(SD|HD|FHD|UHD|4K|8K|[0-9]+p)$", "", tvg_id.lower(), flags=re.I)


def parse_tvg(tvg_id):
    """'ABC.us@East' -> ('abc', 'us', 'east'); quality tags are no sub-feed."""
    head, _, feed = tvg_id.partition("@")
    base, _, country = head.rpartition(".")
    if not base:
        base, country = head, ""
    if QUALITY.match(feed or ""):
        feed = ""
    return alnum(base), country.lower(), alnum(feed)


def playlist_entries(text):
    """[(tvg_id, name)] from M3U text."""
    out = []
    for line in text.splitlines():
        if not line.startswith("#EXTINF:"):
            continue
        quoted = False
        name = ""
        for index, char in enumerate(line):
            if char == '"':
                quoted = not quoted
            if char == "," and not quoted:
                name = line[index + 1:].strip()
                break
        match = re.search(r'tvg-id="([^"]*)"', line)
        out.append((match[1] if match else "", name))
    return out


class Matcher:
    def __init__(self, entries):
        self.entries = []
        for tvg_id, name in entries:
            base, country, feed = parse_tvg(tvg_id) if tvg_id else ("", "", "")
            key = playlist_key(tvg_id) if tvg_id else ""
            regional = feed in REGIONAL or any(w in REGIONAL for w in words(name))
            self.entries.append({"key": key, "base": base, "country": country, "feed": feed,
                                 "name": core_name(name), "regional": regional, "appname": app_name(name)})

    def assign(self, channels, country=""):
        """channels: {feed_id: [display names]} -> {feed_id: {ids, names}}.
        Playlist channels of another country (Free-TV lists the world) are left
        out unless their sub-feed is this country (RedbullTV.at@US)."""
        feed_info = {}
        by_part, by_name = {}, {}
        by_call = {}
        for feed_id, names in channels.items():
            # Local stations by call sign: "WSMV-DT.us_locals1" (the main
            # channel, not -DT2/-DT3 sub-channels).
            call = re.match(r"^([KW][A-Z]{2,3})-(DT|TV|LD|CD|LP)\.", feed_id)
            if call:
                by_call.setdefault(call[1].lower(), feed_id)
            part = alnum(feed_id.rpartition(".")[0] or feed_id)
            label = " ".join([feed_id] + names)
            regional = any(w in REGIONAL for w in words(label))
            feed_info[feed_id] = (part, regional)
            by_part.setdefault(part, []).append(feed_id)
            for n in names:
                core = core_name(n)
                if core:
                    by_name.setdefault(core, []).append(feed_id)
        parts_sorted = sorted(by_part)
        # This country's own tags ("gb" feeds, ".uk" playlist ids).
        home = {country} if country else set()
        if country == "gb":
            home.add("uk")

        def same_country(entry, feed_id):
            # An id match needs the same country tag, or a free streaming
            # service's own tag (TheRifleman.pluto for TheRifleman.us).
            tag = feed_id.rpartition(".")[2].lower().split("_")[0]
            return not home or tag == entry["country"] or tag in FAST or (tag in home and (entry["country"] in home or entry["feed"] in home))

        best = {}
        for entry in self.entries:
            if not entry["key"] and not entry["name"]:
                continue
            local = not home or entry["country"] in home or entry["country"] == "" or entry["feed"] in home
            choice = None
            # 1. base + sub-feed exactly; 2. the plain base id (no sub-feed, or East).
            if entry["feed"] and entry["base"] + entry["feed"] in by_part:
                choice = by_part[entry["base"] + entry["feed"]]
            elif entry["base"] and entry["base"] in by_part and entry["feed"] in ("", "east") or (entry["base"] in by_part and entry["feed"] in home):
                choice = by_part[entry["base"]]
            # 3. an id that starts with base + sub-feed (ABCEast_WABC for ABC@East).
            if choice is None and entry["feed"] and len(entry["base"] + entry["feed"]) >= 4:
                prefix = entry["base"] + entry["feed"]
                hits = [p for p in parts_sorted if p.startswith(prefix)]
                if hits:
                    choice = by_part[min(hits, key=len)]
            if choice:
                choice = [f for f in choice if same_country(entry, f)] or None
            # 3b. a local station by its call sign (ABC.us@KEROTV -> KERO-DT).
            if choice is None and entry["feed"] and local:
                sign = re.sub(r"(tv|dt|hd)$", "", entry["feed"])
                if re.fullmatch(r"[kw][a-z]{2,3}", sign) and sign in by_call:
                    choice = [by_call[sign]]
            # 4. the same core name, East/West kept apart (this country's channels only).
            if choice is None and local and entry["name"] and entry["name"] in by_name:
                same = [f for f in by_name[entry["name"]] if feed_info[f][1] == entry["regional"]]
                choice = same or None
            if choice:
                # Same country first (CNN.us, not CNN.sxm radio), then the shortest id.
                feed_id = min(choice, key=lambda f: (f.rpartition(".")[2].lower() != entry["country"], len(feed_info[f][0])))
                served = best.setdefault(feed_id, {"ids": set(), "names": set()})
                if entry["key"]:
                    served["ids"].add(entry["key"])
                elif entry["appname"]:
                    served["names"].add(entry["appname"])
        return {k: {"ids": sorted(v["ids"]), "names": sorted(v["names"])} for k, v in best.items()}
