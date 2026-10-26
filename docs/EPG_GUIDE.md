# Country EPG setup

zer0 TV preserves every playlist channel, including channels without matching listings. IDs take priority when matching schedules; unique normalized display names are a fallback. Playlist channel logos remain authoritative. Times follow the Roku timezone.

## IPTV.org and Free-TV

`config/epg.json` points to:

```json
{"jsonBase":"https://raw.githubusercontent.com/snuffy420/zer0TV/main/epg/data"}
```

Upload the complete repository folder, including `.github/workflows/epg.yml`, `tools`, `epg` and `config`. Open **Actions → Update country guides → Run workflow** once. If Actions is disabled, enable it. Repository workflow permissions must allow writing contents. The workflow also requests `contents: write`; a repository or organization policy may override it.

The workflow downloads current XMLTV on the GitHub runner, matches stations against the public IPTV.org/Free-TV playlists, and writes compact country JSON under `epg/data`. It commits successful updates every six hours and reports failed countries while preserving their previous files. Check the workflow after the initial run; a green run and recent `generated` values confirm current data. Merely uploading the files does not run the workflow immediately.

Initial countries: US, UK (`gb`), Canada and Australia. Other countries still show playable playlist channels, with no listings until a matching feed is configured. Add lowercase two-letter country keys and XMLTV URLs in `epg/sources.json`. Very large or dense feeds may exceed the 4 MB output cap and require a smaller upstream source.

The Roku fetches only the selected country's JSON. Inputs are limited to 4 MB and accepted for 24 hours after generation. Included snapshots provide a temporary fallback; they also expire after 24 hours. No large original country XML file is loaded on the Roku. Network fallback caches last only for the current app session. A failed guide does not hide channels.

To generate feeds on a computer with Python 3.12 or newer:

```bash
python tools/build_epg.py
```

To switch repository or branch, update `jsonBase`, rebuild the Roku ZIP and install it. Use a raw JSON directory URL without a trailing slash.

## Pluto TV, Samsung TV Plus, Plex and Tubi

These US live sources use the playlist and matching XMLTV URLs in `config/providers.json`. They fetch directly; GitHub JSON hosting is not needed. The parser handles interleaved channel definitions/programmes in 32 KB chunks, with a 64 KB element buffer and 16 MB download cap. A 30-second parse budget and fair per-station limits keep retained schedules under 3,000 programmes. The displayed schedule window is six hours, subject to feed coverage and those limits.

## Refresh and playback

Press * in a live guide to refresh it. Up/Down selects channels; REW/FF jumps letters; Left/Right browses time; Replay searches. Focus preview starts after a brief pause. OK/Play opens full screen. Future listings still tune the live channel; the app does not provide recording or catch-up playback.

Community playlist and EPG providers can change, fail or restrict geographic access. Metadata availability does not guarantee stream playback.
