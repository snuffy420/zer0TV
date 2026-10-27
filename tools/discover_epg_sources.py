"""Discover public country/provider guide coverage; no private movie configuration is read."""
import argparse
import json
import re
import urllib.request
from guide_http import urlopen
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def normalize(value):
    return re.sub(r"[^a-z0-9]", "", value.lower())


def free_regions(playlist, countries):
    names = {normalize(c["name"]): c["code"].lower() for c in countries}
    names.update({"usa": "us", "uk": "gb", "korea": "kr", "trinidad": "tt", "czechrepublic": "cz", "turkey": "tr", "macau": "mo", "japan": "jp", "russia": "ru"})
    return {name: names.get(normalize(name), "group-" + normalize(name)) for name in sorted(set(re.findall(r'group-title="([^"]+)"', playlist)))}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "zer0TV-EPG/1.5", "Accept": "application/vnd.github+json"})
    with urlopen(request, timeout=40) as response:
        return response.read().decode("utf-8-sig")


def country_feeds(html):
    result = {}
    for code in re.findall(r"/files/epg-([a-z]{2})\.xml(?:\.gz)?", html):
        normalized = "gb" if code == "uk" else code
        result[normalized] = f"https://iptv-epg.org/files/epg-{code}.xml.gz"
    if len(result) < 20:
        raise ValueError("Country guide discovery returned too few feeds; retaining current manifest")
    return dict(sorted(result.items()))


def provider_countries(names, provider, xml_names, labels):
    folder = {"plutotv": "PlutoTV", "samsungtvplus": "SamsungTVPlus", "plex": "Plex"}[provider]
    result = []
    for name in sorted(names):
        match = re.fullmatch(re.escape(provider) + r"_([a-z]{2})\.m3u", name)
        if match and match[1] + ".xml" in xml_names:
            code = match[1]
            result.append({"code": code.upper(), "name": labels.get(code, code.upper()), "flag": code.upper(),
                           "playlistUrl": "https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/" + name,
                           "epgUrl": f"https://i.mjh.nz/{folder}/{code}.xml.gz",
                           "liveEpgUrl": f"https://raw.githubusercontent.com/matthuisman/i.mjh.nz/master/{folder}/{code}.xml"})
    return result


def discover(root=ROOT):
    sources = country_feeds(fetch("https://iptv-epg.org/"))
    (root / "epg").mkdir(exist_ok=True)
    (root / "epg/sources.json").write_text(json.dumps(sources, indent=2) + "\n", encoding="utf-8")
    (root / "config/epg-sources.json").write_text(json.dumps(sources, indent=2) + "\n", encoding="utf-8")
    metadata = json.loads(fetch("https://iptv-org.github.io/api/countries.json"))
    labels = {c["code"].lower(): c["name"] for c in metadata}
    labels["gb"] = "United Kingdom"
    regions = free_regions(fetch("https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8"), metadata)
    (root / "config/freetv-regions.json").write_text(json.dumps(regions, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    names = [e["name"] for e in json.loads(fetch("https://api.github.com/repos/BuddyChewChew/app-m3u-generator/contents/playlists"))]
    provider_path = root / "epg/providers.json"
    if not provider_path.exists():
        provider_path.write_text((root / "config/providers.json").read_text(encoding="utf-8"), encoding="utf-8")
    providers = json.loads(provider_path.read_text(encoding="utf-8"))
    for provider in providers:
        if provider["id"] == "tubi":
            continue
        folder = {"plutotv": "PlutoTV", "samsungtvplus": "SamsungTVPlus", "plex": "Plex"}[provider["id"]]
        xml_names = {e["name"] for e in json.loads(fetch("https://api.github.com/repos/matthuisman/i.mjh.nz/contents/" + folder))}
        countries = provider_countries(names, provider["id"], xml_names, labels)
        if countries:
            provider["countries"] = countries
            provider["meta"] = f"Live channels and EPG in {len(countries)} countries"
    provider_path.write_text(json.dumps(providers, indent=2) + "\n", encoding="utf-8")
    print(f"Discovered {len(sources)} country guides and {sum(len(p['countries']) for p in providers)} provider/country lineups")
    return sources, providers


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    discover(parser.parse_args().root)
