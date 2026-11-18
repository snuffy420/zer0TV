# Third-party playlists and notices

zer0 TV is an independent Roku application. It is **not a fork** of the projects below.
It downloads publicly published playlist files over HTTPS at runtime and does not
redistribute video content.

For a complete endpoint-by-endpoint map, see [Sources and data flow](docs/SOURCES.md).

## IPTV.org

- Project: [iptv-org/iptv](https://github.com/iptv-org/iptv)
- Playlist hosts: `https://iptv-org.github.io/iptv/...`
- License: **[The Unlicense](https://github.com/iptv-org/iptv/blob/master/LICENSE)** (public domain dedication)
- Legal note from upstream: the repository stores links to streams, not video files;
  see their [Legal](https://github.com/iptv-org/iptv#legal) section.

## Free-TV IPTV

- Project: [Free-TV/IPTV](https://github.com/Free-TV/IPTV)
- Playlist URL used by this app:
  `https://raw.githubusercontent.com/Free-TV/IPTV/master/playlist.m3u8`
- License: **no SPDX license file is published in that repository** at the time of
  writing. The project documents a free-to-air / free-internet channel philosophy in
  its README. Users and redistributors should review the upstream repository terms
  themselves.

## Stream rights

Individual TV channels and streams remain the property of their respective rights
holders. Upstream playlists and this app only provide links. Availability can change
or be geo-restricted without notice.
## Programme guides

Country guides are built from XMLTV published by [IPTV-EPG.org](https://iptv-epg.org/guides), [epg.pw](https://epg.pw/xmltv.html) and [epgshare01](https://epgshare01.online/epgshare01/). These services are independent of IPTV.org, Free-TV and this app. Their schedule data is not covered by this application's GPL license; review each provider's terms before redistributing the generated JSON. The app keeps playlist-supplied logos and stream URLs.

## Title matching

- [TVmaze](https://www.tvmaze.com/api): show and episode information and artwork, licensed [CC BY-SA 4.0](https://www.tvmaze.com/api#licensing).
- [AniList](https://anilist.co/): anime titles and covers through its public API, under its terms of use.
- IMDb's public title-suggestion endpoint: film titles, years and posters. IMDb data remains subject to IMDb's terms.

## Additional live and on-demand sources

- [BuddyChewChew/app-m3u-generator](https://github.com/BuddyChewChew/app-m3u-generator): public US Pluto TV, Samsung TV Plus and Plex playlist links. The application requests playlists at runtime and does not bundle their video content.
- [matthuisman/i.mjh.nz](https://github.com/matthuisman/i.mjh.nz): matching US provider XMLTV exports. Schedule data remains subject to its upstream terms.
- [Internet Archive](https://archive.org/): public advanced search, item metadata, thumbnails and public video and audio files. Item labels, dates, licenses and descriptions are supplied by uploaders and are not independently verified. Private/restricted files are excluded. Each item's rights and availability remain separate from the app's GPL license.
- [Box://Stream](https://github.com/snuffy420/BoxStream): built in unchanged; it connects only to the media server its user sets up.

The app is independent of these projects and services. Their names and marks identify the selected source and do not imply affiliation or endorsement.

## Source-menu artwork

- IPTV.org and Free-TV avatars: public GitHub organization images.
- Samsung, Plex, Tubi and Internet Archive wordmarks: [Simple Icons](https://simpleicons.org/), CC0 icon artwork. The Samsung wordmark identifies the Samsung TV Plus entry.
- Pluto TV wordmark: [Wikimedia Commons, Pluto TV logo 2024](https://commons.wikimedia.org/wiki/File:Pluto_TV_logo_2024.svg), converted to PNG for Roku.

SVG sources are included for development and omitted from the runtime ZIP. Channel logos and movie posters are fetched from their upstream URLs. All respective trademarks remain with their owners.

## Tubi live channels

[BuddyChewChew/tubi-scraper](https://github.com/BuddyChewChew/tubi-scraper) publishes the live M3U and matching XMLTV feed used by the Tubi source. The app fetches those files when the US lineup opens and retains their channel logos and IDs. It does not run the scraper, use its proxy features or include a Tubi on-demand catalog. Upstream describes these as public, ad-supported streams without DRM; availability and regional restrictions remain controlled by Tubi. The Tubi source-menu wordmark is CC0 artwork from Simple Icons; the trademark belongs to its owner.
