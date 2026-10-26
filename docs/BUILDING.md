# Building zer0 TV 1.5.0

## Runtime ZIP

Python 3.12 or newer is sufficient to package the Roku app:

```bash
python tools/package.py
```

Output: `releases/zer0tv-v1.5.0-roku.zip` and its SHA-256 sidecar. The ZIP contains `manifest`, `source`, `components`, `images` and runtime `config` at its root. Development fixtures, SVG sources, tests, docs and build tools are excluded.

## Source archive

Install the 7-Zip command-line tool (`7z` on PATH, or the standard Windows 7-Zip installation), then run:

```bash
python tools/release.py
```

This builds and integrity-checks the Roku ZIP and a real 7z source archive. `releases`, build output, dependency directories and Python caches are excluded from the source archive. Both artifacts receive checksums.

## Automated checks

Install Node.js and the development tools:

```bash
npm install
npm run check
```

The checks run BrightScript helper/parser tests, fixed-node guide/poster stress tests, playback and worker queue tests, country history and guide-budget tests, Python converter tests, and full BrighterScript compilation. The interpreter is an off-device approximation; actual Roku decoding, remote focus and prolonged playback require a device. Public stream availability varies by region and upstream changes.

The provider JSON fixtures under `config/provider-guides` are deterministic test inputs, not shipped runtime EPG. Regenerate with `python tools/build_provider_guides.py` when investigating provider data. Country guides under `epg/data` are maintained by the included GitHub Actions workflow; see [EPG_GUIDE.md](EPG_GUIDE.md).

## Shared README style

The README follows the OpenLUFS layout: centered app icon/title/tagline, download table, installation, features/controls, development/license, support and contact. `assets/contact-button.svg` and `assets/bitcoin.svg` share that visual style. For another app, change the contact SVG's label, README alt text and destination URL; the SVG is editable and does not depend on an external image service.
