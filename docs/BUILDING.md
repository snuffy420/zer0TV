# Building zerØ TV

## Box://Stream

zerØ TV builds [Box://Stream](https://github.com/snuffy420/BoxStream) in unchanged. Packaging copies its files from a `boxstream-roku` folder next to this one (`tools/boxstream_bundle.py`):

```
some-folder/
  zer0tv-public/      this repository
  boxstream-roku/     the Box://Stream repository
```

## Roku ZIP

Python 3.12 or newer with Pillow:

```bash
python tools/package.py
```

Each build gets the next version (2.5.5 → 2.5.6; a .9 rolls over, 2.5.9 → 2.6.0) and redraws the splash with it. `--same` keeps the current version. Output: `releases/zer0tv-v<version>-roku.zip` with its SHA-256. The ZIP holds `manifest`, `source`, `components`, `images`, `config` and `fonts`; tests, docs and tools stay out. Roku's store limit is 4 MB; the ZIP is about 3 MB.

`tools/build_glow_assets.py` draws the interface artwork (cards, glows, chips, icons, splash and app icons).

## Release

Install 7-Zip (`7z` on PATH, or the standard Windows install), then:

```bash
python tools/release.py
```

This builds the Roku ZIP and a 7z source archive of this repository, tests the archive and writes checksums for both.

## Checks

Install Node.js, then:

```bash
npm install
npm run check
```

The checks run the BrightScript tests (guide, guide budgets and matching, playback, quick panel, countries, Internet Archive grid and search), the Python guide-builder tests and a full BrighterScript compile. They run off the device; remote focus, decoding and long playback need a Roku.

Country guides under `epg/data` are kept current by the GitHub workflow; see [EPG_GUIDE.md](EPG_GUIDE.md). The JSON under `config/provider-guides` are test fixtures.
