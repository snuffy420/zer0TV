# Programme guides

zerØ TV keeps every playlist channel in the guide, including channels without listings; those still play. Times follow the Roku's time zone.

## IPTV.org and Free-TV

The Roku reads one compact JSON file per country from this repository:

```json
{"jsonBase":"https://raw.githubusercontent.com/snuffy420/zer0TV/main/epg/data"}
```

The **Update all public guides** workflow (`.github/workflows/epg.yml`) builds those files every six hours, and whenever the guide tools change. It needs GitHub Actions enabled with permission to write repository contents. You can also start it by hand: **Actions → Update all public guides → Run workflow**.

### Feeds

Each run finds its feeds itself, so new countries are picked up without changes here:

| Feed | Used for |
| --- | --- |
| [IPTV-EPG.org](https://iptv-epg.org/guides) country files | Every country in `epg/sources.json` (refreshed by `tools/discover_epg_sources.py`) |
| [epg.pw](https://epg.pw/xmltv.html) country files | Every country listed on its index page |
| [epgshare01](https://epgshare01.online/epgshare01/) country files | Every country on its index page (`UK1` is gb; `US_LOCALS1` and `US_SPORTS1` are us) |
| epgshare01 service feeds | Every country: Plex, Peacock, Rakuten, Whale TV+, AMC, TBN+, DistroTV, Al Jazeera, VOA, beIN, SportKlub and others |
| `epg/extra-sources.json` | Anything else, by country code, or `"*"` for every country |

Each feed is downloaded and read once per run, however many countries use it. A run takes about 10 minutes.

### Matching

For each country the IPTV.org country playlist and the Free-TV playlist are matched to the feeds in order (`tools/epg_match.py`); a later feed only adds channels the earlier ones missed. A playlist channel matches a feed channel by:

1. its id with the sub-feed: `ABC.us@KAAL` → `ABCKAAL.us`;
2. its plain id: `CNN.us@SD` → `CNN.us`;
3. an id that starts with id and sub-feed: `ABC.us@East` → `ABCEast_WABC.us`;
4. a local station's call sign: `ABC.us@KEROTV` → `KERO-DT`;
5. the same name, ignoring words like Network, Television and Entertainment: `A&E` → `A&E Network`.

East and West feeds are kept apart, id matches need the same country (or a streaming service's own tag such as `.pluto`), Free-TV channels from other countries never take this country's listings, and radio feeds are never used. Each output channel lists the playlist ids and names it serves, so the Roku finds listings under the playlist's own `tvg-id`.

Listings run from an hour ago to 18 hours ahead, so a guide stays useful if a run fails. Files stay under 4 MB. A country with no matching listings keeps its previous file. `epg/data/country-status.json` reports every country's coverage and feeds.

### On the Roku

The Roku downloads only the country you open. It keeps the next six hours for each channel (up to 6,000 programmes in all, shared by the channels that have listings), and saves the result for 30 minutes so reopening is instant; a saved guide up to 5 hours old shows straight away while a fresh one downloads. Guides older than 24 hours are not used.

To build guides on a computer (Python 3.12 or newer):

```bash
python tools/update_all_guides.py
python tools/build_epg.py --only us gb
```

To use another repository or branch, change `jsonBase` in `config/epg.json` and rebuild the Roku ZIP.

## Pluto TV, Samsung TV Plus, Plex and Tubi

These US sources use the playlist and XMLTV URLs in `config/providers.json` and download their guide directly when the lineup opens. The parser reads the XMLTV in 32 KB chunks with a 16 MB download cap.

## Coverage

Most free streaming channels in the community playlists are not listed by any free guide, so they show "No listings · OK to watch live". Guide coverage, titles and streams depend on the upstream feeds and regional restrictions.
