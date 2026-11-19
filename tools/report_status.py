"""End of a guide run: say what failed, and turn the run red only for real breakage.

An upstream feed that is down or stale (a Tubi scraper that stopped updating,
a rate-limited discovery call) is shown as a warning on the run: every guide
that could be built was published and the others keep their last good file.
The run fails only when many country guides fail or nothing was built.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = ROOT / "epg/data"
MAX_FAILED_COUNTRIES = 8


def load(name):
    try:
        return json.loads((data / name).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


status = load("update-status.json")
countries = load("country-status.json")
providers = load("providers/provider-status.json")
if status is None or countries is None:
    print("::error::The guide run produced no status files.")
    sys.exit(1)

for failure in status.get("failures", []):
    print("::warning::" + failure)
if providers:
    for feed in providers.get("feeds", []):
        if feed.get("status") != "ok":
            print(f"::warning::{feed['provider']}/{feed['country']}: {feed.get('error', 'failed')}")
failed = [f["country"] for f in countries.get("feeds", []) if f.get("status") == "failed"]
built = sum(1 for f in countries.get("feeds", []) if f.get("status") == "ok")
for country in failed:
    print(f"::warning::country guide {country} failed; its previous file is kept")
print(f"{built} country guides built, {len(failed)} failed.")
if built == 0 or len(failed) > MAX_FAILED_COUNTRIES:
    print("::error::Too many country guides failed.")
    sys.exit(1)
