# Programme guide updates

GitHub Actions refreshes discovered country feeds, provider/country lineups, and matching Free-TV groups every six hours. Enable Actions after upload; the workflow also supports Run workflow. Successful updates are published even if another upstream feed fails; previous usable data is preserved and failures are reported.

`epg/data/us.json` is the generated US feed, alongside the other country files. The app fetches only the selected country and refreshes while browsing. Channels without matching listings remain visible and playable. Programme availability depends on upstream coverage.

See country-status.json, providers/provider-status.json and update-status.json in epg/data for coverage and update results. Scheduled jobs may be delayed by GitHub.
