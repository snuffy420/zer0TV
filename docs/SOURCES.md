# Sources and data flow

zerØ TV 2.5.7 has eight sources: six live TV playlists, the Internet Archive and Box://Stream. No provider account is needed. Feed availability and geographic restrictions are controlled by the upstream services.

## Live playlists

| Source | Project | Playlist the app downloads |
| --- | --- | --- |
| IPTV.org | [iptv-org/iptv](https://github.com/iptv-org/iptv) | [Country playlists](https://iptv-org.github.io/iptv/countries/us.m3u), with the country code in place of `us` |
| Free-TV IPTV | [Free-TV/IPTV](https://github.com/Free-TV/IPTV) | [Global playlist](https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8) |
| Pluto TV | [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator) | [Pluto US](https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/plutotv_us.m3u) and other countries |
| Samsung TV Plus | [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator) | [Samsung US](https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/samsungtvplus_us.m3u) |
| Plex Live TV | [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator) | [Plex US](https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/plex_us.m3u) |
| Tubi | [BuddyChewChew/tubi-scraper](https://github.com/BuddyChewChew/tubi-scraper) | [Tubi live](https://raw.githubusercontent.com/BuddyChewChew/tubi-scraper/main/tubi_playlist.m3u) |

These are community playlist projects, separate from the named TV services. zerØ TV downloads their published files; it does not run their scrapers. Channel names, ids and logos come from the playlists.

## Programme guides

| Source | Guide | How the app gets it |
| --- | --- | --- |
| IPTV.org, Free-TV | [IPTV-EPG.org](https://iptv-epg.org/guides), [epg.pw](https://epg.pw/xmltv.html), [epgshare01](https://epgshare01.online/epgshare01/) | The GitHub workflow matches the feeds to the playlists and publishes one JSON per country in [`epg/data`](https://github.com/snuffy420/zer0TV/tree/main/epg/data); the Roku downloads the country you open |
| Pluto TV, Samsung TV Plus, Plex | [matthuisman/i.mjh.nz](https://github.com/matthuisman/i.mjh.nz) | XMLTV downloaded when the lineup opens |
| Tubi | [BuddyChewChew/tubi-scraper](https://github.com/BuddyChewChew/tubi-scraper) | XMLTV downloaded when the lineup opens |

See [Programme guides](EPG_GUIDE.md) for the feeds, matching rules and schedule.

## Internet Archive

- [Advanced search](https://archive.org/advancedsearch.php): every section, chip and search is a live search; there is no built-in title list.
- [Metadata API](https://archive.org/developers/md-read.html) `https://archive.org/metadata/{identifier}/files`: video lengths, episode files, chapters and thumbnails.
- Artwork: `https://archive.org/services/img/{identifier}` and the Archive's own per-file thumbnails.
- Playback: `https://archive.org/download/{identifier}/{file}`.

Titles, labels and runtimes come from what uploaders publish. Availability and rights are handled by the Internet Archive.

### Matching services

| Service | Used for |
| --- | --- |
| IMDb title suggestions (`v3.sg.media-imdb.com`) | Film titles, years and posters; grouping copies of the same film |
| [TVmaze API](https://www.tvmaze.com/api) | TV show names, posters, backgrounds, logos, episode titles, air dates, descriptions and pictures |
| [AniList API](https://anilist.gitbook.io/anilist-apiv2-docs/) | Anime English titles, covers and years |

A match is used only when the names agree; otherwise the Archive's own title and artwork are shown.

## Box://Stream

[Box://Stream](https://github.com/snuffy420/BoxStream) is built in unchanged and connects only to the server you set up in it.

## Artwork and attribution

- Source cards: IPTV.org and Free-TV organisation images; Samsung, Plex, Tubi and Internet Archive marks from [Simple Icons](https://simpleicons.org/) (CC0); Pluto TV from [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Pluto_TV_logo_2024.svg).
- Country flags: [flagcdn.com](https://flagcdn.com/).
- Channel logos and title artwork: the playlists and services listed above. TVmaze data is [CC BY-SA 4.0](https://www.tvmaze.com/api#licensing).
- Interface artwork, splash and icons: drawn by `tools/build_glow_assets.py`.

Application code is GPL-3.0; that license does not cover third-party data, logos or video. Names and marks identify their services; zerØ TV is not affiliated with them. See [THIRD_PARTY.md](../THIRD_PARTY.md).
