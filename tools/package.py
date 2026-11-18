"""Package the runtime at the ZIP root for the Roku developer installer.

Box://Stream's files come straight from ../boxstream-roku (see boxstream_bundle.py).
Every build raises the version (2.0.8 -> 2.0.9 -> 2.1.0; pass --same to keep it)
and redraws the splash with that version."""
import hashlib
import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import boxstream_bundle  # noqa: E402

root = Path(__file__).resolve().parents[1]
if "--same" not in sys.argv:
    # Each part is one digit: 2.0.9 is followed by 2.1.0, and 2.9.9 by 3.0.0.
    text = (root / "manifest").read_text(encoding="utf-8")
    major, minor, build = (int(re.search(rf"{k}_version=(\d+)", text).group(1)) for k in ("major", "minor", "build"))
    build += 1
    if build > 9:
        build = 0
        minor += 1
    if minor > 9:
        minor = 0
        major += 1
    for key, value in (("major", major), ("minor", minor), ("build", build)):
        text = re.sub(rf"{key}_version=\d+", f"{key}_version={value}", text)
    (root / "manifest").write_text(text, encoding="utf-8", newline=chr(10))
# The splash shows the version, so it is redrawn for every build.
import subprocess  # noqa: E402
subprocess.run([sys.executable, str(root / "tools" / "build_glow_assets.py"), "--splash"], check=True)
manifest = (root / "manifest").read_text(encoding="utf-8")
version = ".".join(re.search(rf"{k}_version=(\d+)", manifest).group(1) for k in ("major", "minor", "build"))
output = root / f"releases/zer0tv-v{version}-roku.zip"
output.parent.mkdir(exist_ok=True)
names = set()
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    def add(path, name):
        assert name not in names, f"two files would be packaged as {name}"
        names.add(name)
        archive.write(path, name)

    add(root / "manifest", "manifest")
    for folder in ("source", "components", "images", "config", "fonts"):
        for path in sorted((root / folder).rglob("*")):
            if path.is_file() and "provider-guides" not in path.parts and path.suffix != ".svg" and path.name != "curated.json":
                add(path, path.relative_to(root).as_posix())
    for path, name in boxstream_bundle.files():
        add(path, name)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for required in ("manifest", "components/EpgTask.xml", "components/BoxStreamApp.xml"):
        assert required in archive.namelist(), required
size = output.stat().st_size
if size >= 4 * 1024 * 1024:
    # Fine for sideloading (developer builds); the Channel Store would refuse it.
    print(f"note: {size} bytes is over the Channel Store's 4 MB limit (sideloading is fine)")
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(".zip.sha256").write_text(f"{digest}  {output.name}\n")
print(f"{output}\n{size} bytes\nSHA256 {digest}")
