# Automatic public programme guides

Upload the contents of this folder into the existing repository, preserving paths. This is an optional data/tool update; it does not modify the public app or its main README. It contains no private movie sources, connections or keys.

Enable GitHub Actions. Uploading the workflow triggers a refresh; it can also be started manually with Run workflow. Thereafter it runs every six hours. GitHub may delay scheduled runs. Successful updates are committed automatically; upstream failures keep prior files and produce an error report.

`epg/data/us.json` is the generated US guide. The upload includes four starter country guides and four US provider guides; the workflow generates the other available countries, provider/country lineups and matching Free-TV thematic groups. It rediscovers feed availability on every run. No feed can supply listings that the upstream source does not publish.

Coverage and failures are recorded in `epg/data/country-status.json`, `epg/data/providers/provider-status.json`, and `epg/data/update-status.json`. Channels without matching listings remain available in the app. Roku loads only its selected country, refreshes while browsing, and uses bounded fallback parsing where supported by its build.

The public app's future UI and EPG routing changes remain backlog items. This upload provides guide data and automation, not the private application.
