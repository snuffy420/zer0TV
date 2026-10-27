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
