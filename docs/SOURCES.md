# Sources and data flow

zer0 TV 1.5.0 has eight source entries. Six browse live TV and two browse on-demand catalogs. No provider account is required by this app. Public feed availability and geographic playback restrictions remain controlled by upstream services.

## Live playlists

| Entry | Project | Runtime playlist |
| --- | --- | --- |
| IPTV.org | [iptv-org/iptv](https://github.com/iptv-org/iptv) | [Country playlists](https://iptv-org.github.io/iptv/countries/us.m3u), with the selected country code replacing `us` |
| Free-TV IPTV | [Free-TV/IPTV](https://github.com/Free-TV/IPTV) | [Global playlist](https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8) |
| Pluto TV, US | [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator) | [Pluto US](https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/plutotv_us.m3u) |
| Samsung TV Plus, US | [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator) | [Samsung US](https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/samsungtvplus_us.m3u) |
| Plex Live TV, US | [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator) | [Plex US](https://raw.githubusercontent.com/BuddyChewChew/app-m3u-generator/main/playlists/plex_us.m3u) |
| Tubi, US | [BuddyChewChew/tubi-scraper](https://github.com/BuddyChewChew/tubi-scraper) | [Tubi live](https://raw.githubusercontent.com/BuddyChewChew/tubi-scraper/main/tubi_playlist.m3u) |

These are third-party community playlist projects, separate from the named TV services. zer0 TV requests their published files; it does not execute their scrapers or proxy routines. Channel names, station IDs and logo URLs come from those playlists. All channels remain visible when guide matching fails. The Tubi entry provides live channels, not its on-demand library.

## Electronic programme guides

| Live source | Upstream guide | App behavior |
| --- | --- | --- |
| IPTV.org / Free-TV | [IPTV-EPG.org](https://iptv-epg.org/guides), independent of both playlist projects | GitHub Actions converts configured country XMLTV to compact JSON; Roku fetches the selected country from [this repository's guide data](https://github.com/snuffy420/zer0TV/tree/main/epg/data) |
| Pluto TV | [matthuisman/i.mjh.nz](https://github.com/matthuisman/i.mjh.nz), [Pluto US XMLTV](https://raw.githubusercontent.com/matthuisman/i.mjh.nz/master/PlutoTV/us.xml) | Fresh bounded XMLTV download when the lineup opens |
| Samsung TV Plus | [matthuisman/i.mjh.nz](https://github.com/matthuisman/i.mjh.nz), [Samsung US XMLTV](https://raw.githubusercontent.com/matthuisman/i.mjh.nz/master/SamsungTVPlus/us.xml) | Fresh bounded XMLTV download when the lineup opens |
| Plex Live TV | [matthuisman/i.mjh.nz](https://github.com/matthuisman/i.mjh.nz), [Plex US XMLTV](https://raw.githubusercontent.com/matthuisman/i.mjh.nz/master/Plex/us.xml) | Fresh bounded XMLTV download when the lineup opens |
| Tubi | [BuddyChewChew/tubi-scraper](https://github.com/BuddyChewChew/tubi-scraper), [Tubi XMLTV](https://raw.githubusercontent.com/BuddyChewChew/tubi-scraper/main/tubi_epg.xml) | Fresh bounded XMLTV download when the lineup opens |

Configured original-country XMLTV feeds are `https://iptv-epg.org/files/epg-{country}.xml.gz` for `us`, `gb`, `ca` and `au`. Their full files are processed on the GitHub runner rather than loaded into Roku memory. `config/epg.json` points to `https://raw.githubusercontent.com/snuffy420/zer0TV/main/epg/data`; `epg/sources.json` controls the converter inputs. See [EPG setup](EPG_GUIDE.md) for the initial workflow run and update schedule.

## On-demand catalogs and metadata

### Pluto On Demand

- Catalog project: [OwnerPlugins/pluto-tv-m3u](https://github.com/OwnerPlugins/pluto-tv-m3u).
- Published catalog: [Pluto US VOD M3U](https://raw.githubusercontent.com/OwnerPlugins/pluto-tv-m3u/main/pluto-vod-US.m3u).
- Title metadata: Pluto's public episode endpoint, `https://api.pluto.tv/v2/episodes/{episode_id}`.
- Posters: `https://images.pluto.tv/episodes/{episode_id}/poster.jpg`.
- Playback: the current title link from a freshly requested catalog.

The feed is a selection and may contain show episodes as well as movies. It does not promise the complete Pluto catalog. Availability, images and descriptions can change independently.

### Internet Archive

- [Internet Archive advanced search](https://archive.org/advancedsearch.php): public movie-item discovery, title/subject search and filter results.
- [Metadata API](https://archive.org/developers/md-read.html): `https://archive.org/metadata/{identifier}` for item information and compatible public-file selection.
- Thumbnails: `https://archive.org/services/img/{identifier}`.
- Playback: public MP4 files at `https://archive.org/download/{identifier}/{filename}`.

Rare finds, workprints, alternate cuts, trailers, production footage and public-domain-marked classics are discovery filters over uploader metadata. The app does not certify authenticity, completeness or rights status. Private/restricted files are excluded, and not every result has a compatible playable MP4.

## Artwork and attribution

- Source-menu IPTV.org and Free-TV avatars: public GitHub organization images.
- Samsung, Plex, Tubi and Internet Archive wordmarks: [Simple Icons](https://simpleicons.org/), CC0 icon artwork. The Samsung wordmark identifies TV Plus.
- Pluto TV wordmark: [Wikimedia Commons, Pluto TV logo 2024](https://commons.wikimedia.org/wiki/File:Pluto_TV_logo_2024.svg).
- Channel logos and movie artwork: the playlist and metadata sources listed above.
- The app's contact and Bitcoin SVG buttons follow the shared OpenLUFS README style.

Application source is GPL-3.0. That license does not relicense third-party data, logos or video. Names and marks identify their services; the app is unaffiliated. See [THIRD_PARTY.md](../THIRD_PARTY.md).
