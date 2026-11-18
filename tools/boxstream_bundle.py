"""Box://Stream inside zer0TV: the very same files as the standalone app.

zer0TV keeps no copy of Box://Stream. Packaging pulls its runtime straight from
the boxstream-roku folder next to this project, so both apps always ship the
same code. Left out: Box://Stream's manifest, its source/main.brs and its
standalone MainScene (zer0TV has its own), and its launch splash and icons.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOXSTREAM = ROOT.parent / "boxstream-roku"
SKIP = {
    "components/MainScene.xml", "components/MainScene.brs",
    "images/splash_fhd.png", "images/splash_hd.png",
    "images/icon_fhd.png", "images/icon_hd.png", "images/icon_sd.png",
}


def files():
    """(source path, path in the package) for every Box://Stream runtime file."""
    if not (BOXSTREAM / "components" / "BoxStreamApp.xml").is_file():
        raise SystemExit(f"Box://Stream not found at {BOXSTREAM}")
    for folder in ("components", "images", "fonts"):
        for path in sorted((BOXSTREAM / folder).rglob("*")):
            name = path.relative_to(BOXSTREAM).as_posix()
            if path.is_file() and name not in SKIP and path.suffix.lower() not in (".svg", ".gif"):
                yield path, name


def stage(target):
    """Copies Box://Stream's runtime files into target (for the compiler check)."""
    import shutil
    target = Path(target)
    for source, name in files():
        out = target / name
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, out)


if __name__ == "__main__":
    items = list(files())
    print(len(items), "files,", sum(p.stat().st_size for p, _ in items), "bytes")
