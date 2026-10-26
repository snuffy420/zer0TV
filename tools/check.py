"""Run the off-device stability checks with explicit compiler/interpreter paths."""
import argparse
import subprocess
import sys
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--brs", default="brs")
parser.add_argument("--bsc", default="bsc")
args = parser.parse_args()
args.brs = shutil.which(args.brs) or args.brs
args.bsc = shutil.which(args.bsc) or args.bsc
cases = [
    ["components/MovieCommon.brs", "components/EpgUtils.brs", "tests/test_movies.brs"],
    ["components/MovieUI.brs", "components/MovieCommon.brs", "components/EpgUtils.brs", "tests/test_movie_grid.brs"],
    ["components/SourceMenu.brs", "tests/test_source_menu.brs"],
    ["components/Providers.brs", "components/EpgUtils.brs", "components/EpgStore.brs", "tests/test_provider_guides.brs"],
    ["components/CountryUI.brs", "tests/test_countries.brs"],
    ["components/PlayerUI.brs", "tests/test_guide_letters.brs"],
    ["components/Guide.brs", "components/EpgUtils.brs", "components/PlayerUI.brs", "tests/test_player_ui.brs"],
    ["components/EpgUtils.brs", "tests/test_epg.brs"],
    ["components/PlaylistTask.brs", "tests/test_playlist.brs"],
    ["components/Guide.brs", "components/EpgUtils.brs", "tests/test_guide.brs"],
    ["components/Guide.brs", "components/EpgUtils.brs", "tests/test_playback.brs"],
    ["components/Guide.brs", "components/EpgUtils.brs", "components/Countries.brs", "components/Providers.brs", "tests/test_guide_worker.brs"],
    ["components/EpgStore.brs", "tests/test_epg_store.brs"],
    ["components/EpgStore.brs", "components/EpgUtils.brs", "tests/test_country_json.brs"],
]
for case in cases:
    result = subprocess.run([args.brs, *case], cwd=root, capture_output=True, text=True, encoding="utf-8")
    output = result.stdout + result.stderr
    print(output.strip())
    # Some interpreter errors return exit status zero, so require a positive test marker.
    if result.returncode or "PASS:" not in output or "FAIL:" in output:
        raise SystemExit(f"BrightScript check failed: {case[-1]}")
subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-v"], cwd=root, check=True)
subprocess.run([args.bsc, "--rootDir", ".", "--files", "source/**/*", "components/**/*", "config/**/*", "manifest", "images/**/*", "--copyToStaging", "false", "--createPackage", "false"], cwd=root, check=True)
print("PASS: all stability checks and compilation")
