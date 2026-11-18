## 2.5.7 - November 18, 2026

The 2.x series rebuilds zerØ TV at 1080p with a new look on every screen, builds Box://Stream in, and replaces the Internet Archive browser.

**Look and feel**
- New 1080p design on every screen: dark background, green and cyan glow, logo cards, real remote-button hints and no filler text.
- New splash screen and app icon; the version on the splash updates with every build.
- Source screen: eight logo cards with centred names.

**Countries**
- Flag grid, with country names that always fit. Opened countries pin themselves to the top; Replay pins or unpins. The pin sits clear of the focus glow.
- Every Free-TV country shows its flag, including Korea, Macau, Trinidad, Turkey, UK, USA and Japan.

**Live guide**
- Five-row rolling guide with bigger logos, full channel numbers (up to four digits), a thin now line over the grid, arrows on programmes that started earlier, and a large channel logo under NOW PLAYING.
- Left/Right jumps A–Z, REW/FF moves through time.
- Scan (Play): the rows roll through the lineup and a channel is previewed every 45 seconds.
- No title, time or "Tuning" text flashes over the preview when changing channel; Roku's own player overlays are off.
- Channel search uses a QWERTY keyboard, and its results no longer run into the button hints.

**Full screen**
- Up/Down flips channels. Replay opens a channel panel with what's on now. The banner shows the programme, time left and the buttons, then fades.

**Programme guides**
- IPTV.org and Free-TV guides cover 88 countries, rebuilt every six hours from every free XMLTV feed found: IPTV-EPG.org, epg.pw, and epgshare01 country and service feeds (Plex, Peacock, Rakuten, Whale TV+, AMC, TBN+, DistroTV and more). New countries from those feeds are picked up automatically.
- Channels are matched across naming differences (`AE.us@East` = `AandENetwork.us`), sub-feeds and local stations by call sign, while keeping East and West apart, never using another country's listings for Free-TV's foreign channels, and never using radio listings. The US guide went from about 230 channels with listings to more than 750.
- The listings budget is shared by the channels that have listings (6,000 programmes), so every listed channel fills the six-hour window.
- Guides load about 2.5 times faster on the Roku. A guide saved within 30 minutes opens instantly, and one up to 5 hours old shows straight away while a fresh one downloads.

**Internet Archive**
- Everything is found live; there is no built-in title list. Rows scroll endlessly.
- Tabs: Anime (Movies, TV Shows), Audiobooks, Movies, TV Shows, Trailers, Favorites and Search. Movies has decades from the 1950s to the 2000s plus Workprints, Screeners, 35mm, Open Matte and Laser Disc / VHS.
- Films are an hour or more (workprints 30 minutes). Copies of a film are grouped as versions, with DVD extras alongside; items holding several films are split.
- TV Shows lists full seasons only, several seasons in one item included, with TVmaze backgrounds, logos, episode titles, air dates, descriptions and pictures. Episodes without a TVmaze picture use the Archive's own thumbnail.
- Anime uses AniList for English titles and covers. Audiobooks play as chapters. Trailers are 35mm scans.
- Every film and show opens one page laid out like Box://Stream, with horizontal cards for episodes, chapters, versions and extras. Card text ends on whole words, never "...".
- Search asks Movies, TV Shows or Everything, and tries the exact phrase, all words, tags and descriptions, then spelling tolerance.
- Favorites, and an Adult section that is off unless switched on in the * menu.
- Faster: file lists stop waiting once most have answered, AniList is asked once per page, and section pages are saved for 6 hours.
- Fixes: a crash that froze Anime, the tab highlight on the wrong tab while loading, and overlapping labels.

**Box://Stream**
- The full Box://Stream app is built in unchanged as a source. Its saved settings carry over from a previous sideload.

**Removed**
- Pluto On Demand (Pluto TV live channels stay).

## 1.5.5 - October 27, 2026

- Add a themed in-panel movie details page with artwork, synopsis, available metadata and an explicit Play action. Keep the top header and right information panel visible.
- Replace the native movie search dialog with the channel-style keyboard. Submit explicitly with Search or Play; prevent held OK presses and delayed playback results from opening a movie while typing.
- Add an on-demand elapsed/total timeline and seek preview: Left/Right moves 10 seconds, REW/FF moves one minute, OK confirms, and Back cancels. Preserve paused state; enable seeking only when duration is known.
- Fix hidden menu focus and navigation to partially filled poster rows. Release inactive poster artwork before playback.
- Expand live-provider country selection and country-specific playlist/EPG routing across available public feeds. Keep channels with no matching programme data visible and playable.
- Refresh guides automatically every six hours through GitHub Actions, rediscover available feeds, retain successful updates when another upstream fails, and publish coverage reports.
- Bound guide downloads, parsing, caches and per-channel programme counts; refresh the four bundled fallback guides.
- Update About, startup text, installer version and both splash-screen sizes to 1.5.5.
- Keep all eight public sources and existing public favorites/history settings. No private sources, resolvers, helper connections or access keys are included.

The current public on-demand feeds provide movie/episode items; this release does not invent a series catalog where a source supplies none. New search/details, seeking and expanded country playback need Roku device testing; off-device validation is recorded with the release.

# Changelog

## 1.5.0

- Add a modern country EPG with channel logos, live preview and full-screen playback. Channels without listings remain visible and playable.
- Add Pluto TV, Samsung TV Plus, Plex and Tubi US live sources with matching guides.
- Add separate Pluto On Demand and Internet Archive browsers with posters, metadata, search and paging.
- Add Archive discovery filters for rare finds, workprints, alternate cuts, trailers, behind-the-scenes footage and public-domain-marked classics.
- Refresh catalogs on opening and resolve current movie playback files before play; use session-only network fallback caches.
- Introduce larger source-menu logo cards in the existing neon theme.
- Add A–Z guide jumps, channel search, persistent country pins and recently viewed countries for both original playlist sources.
- Add captions/audio options, movie seeking and a fading information banner anchored to the screen bottom.
- Reuse guide rows, poster cards, background workers and a single video decoder; bound retained schedules and serialize playback transitions.
- Configure repository-hosted country EPG updates for IPTV.org and Free-TV through GitHub Actions.
- Display 1.5.0 on the splash and About screen, without build labels.
- Refresh the README with real Roku screenshots, a linked source register, shared contact-button style, install instructions and third-party notices.

## 1.0.2

- Country-based IPTV.org and Free-TV browser with channel search, logos, favorites and HLS playback.
- On-screen keyboard, playback options, donation QR and contact page.
