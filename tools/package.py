"""Package the runtime at the ZIP root for the Roku developer installer."""
import hashlib
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
output = root / "releases/zer0tv-v1.5.5-roku.zip"
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.write(root / "manifest", "manifest")
    for folder in ("source", "components", "images", "config"):
        for path in sorted((root / folder).rglob("*")):
            if path.is_file() and "provider-guides" not in path.parts and path.suffix != ".svg":
                archive.write(path, path.relative_to(root).as_posix())
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert "manifest" in archive.namelist()
    assert "components/EpgTask.xml" in archive.namelist()
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(".zip.sha256").write_text(f"{digest}  {output.name}\n")
print(f"{output}\nSHA256 {digest}")
