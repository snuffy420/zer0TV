"""Build the Roku ZIP and a genuine 7z source archive with checksums."""
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
# The version the manifest already has (no bump): the release is that build.
subprocess.run([sys.executable, str(root / "tools/package.py"), "--same"], check=True)
manifest = (root / "manifest").read_text(encoding="utf-8")
version = ".".join(re.search(rf"^{k}_version=(\d+)", manifest, re.M)[1] for k in ("major", "minor", "build"))
sevenzip = shutil.which("7z") or shutil.which("7zz")
if not sevenzip:
    candidate = Path("C:/Program Files/7-Zip/7z.exe")
    if candidate.is_file():
        sevenzip = str(candidate)
if not sevenzip:
    raise SystemExit("Install 7-Zip and place 7z on PATH to build the source archive.")
output = root / f"releases/zer0tv-v{version}-source.7z"
excluded = {"releases", ".git", "__pycache__", "node_modules", ".staging", "out", "archive", "github-upload-epg", "github-upload"}
files = [p.relative_to(root).as_posix() for p in sorted(root.rglob("*"))
         if p.is_file() and not set(p.relative_to(root).parts) & excluded
         and p.suffix not in {".pyc", ".log"}
         # Generated guides live on GitHub (refreshed every six hours), not in the source.
         and not p.relative_to(root).as_posix().startswith("epg/data/")]
# Remove only this exact generated archive before rebuilding; never update an old archive in place.
output.unlink(missing_ok=True)
listing = root / "releases/source-files.lst"
try:
    listing.write_text("\n".join(files) + "\n", encoding="utf-8")
    subprocess.run([sevenzip, "a", "-t7z", "-mx=7", "-mmt=2", "-scsUTF-8", str(output), "@" + str(listing)], cwd=root, check=True)
finally:
    listing.unlink(missing_ok=True)
subprocess.run([sevenzip, "t", str(output)], check=True)
assert output.read_bytes()[:6] == b"7z\xbc\xaf\x27\x1c"
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(".7z.sha256").write_text(f"{digest}  {output.name}\n")
print(f"{output}\nSHA256 {digest}")
