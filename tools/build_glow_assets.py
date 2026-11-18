"""Builds the Glow Grid artwork zer0TV 2.0 draws its screens with (1080p).

  images/glow/bg.jpg       dark ground with a soft cyan and green glow
  images/glow/logo.png     the zerØ TV mark and name
  images/glow/card.9.png   rounded card (white; tinted in the app)
  images/glow/focus.9.png  green focus ring with its glow (36 px margin all round)
  images/glow/chip.9.png   round-ended chip
Run:  python tools/build_glow_assets.py   (add --splash to redraw only the
launch splash with the manifest's version; tools/package.py does that every build)
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "images", "glow")
BOLD = "C:/Windows/Fonts/segoeuib.ttf"

GROUND = (7, 11, 18)
GREEN = (57, 255, 20)
CYAN = (0, 200, 255)


def radial(size, center, radii, color, strength):
    w, h = size
    layer = Image.new("L", size, 0)
    d = ImageDraw.Draw(layer)
    cx, cy = center
    rx, ry = radii
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=int(255 * strength))
    layer = layer.filter(ImageFilter.GaussianBlur(max(rx, ry) // 3))
    tint = Image.new("RGB", size, color)
    return tint, layer


def background():
    w, h = 1920, 1080
    img = Image.new("RGB", (w, h), GROUND)
    for center, radii, color, strength in [
        ((int(w * 0.18), 0), (1350, 630), CYAN, 0.10),
        ((w, int(h * 0.30)), (1050, 570), GREEN, 0.06),
    ]:
        tint, mask = radial((w, h), center, radii, color, strength)
        img = Image.composite(tint, img, mask)
    img.save(os.path.join(OUT, "bg.jpg"), quality=90)


def nine_patch(img, stretch_x, stretch_y):
    """Adds Roku's 1 px nine-patch border: black marks the stretchable rows/columns."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    d = ImageDraw.Draw(out)
    d.line([(1 + stretch_x[0], 0), (stretch_x[1], 0)], fill=(0, 0, 0, 255))
    d.line([(0, 1 + stretch_y[0]), (0, stretch_y[1])], fill=(0, 0, 0, 255))
    return out


def rounded(size, radius, fill, outline=None, width=0, scale=4):
    w, h = size
    big = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], radius * scale, fill=fill,
                        outline=outline, width=width * scale)
    return big.resize((w, h), Image.LANCZOS)


def card():
    # White, so the app can tint it with blendColor.
    img = rounded((64, 64), 18, (255, 255, 255, 255))
    nine_patch(img, (24, 40), (24, 40)).save(os.path.join(OUT, "card.9.png"))


def focus():
    margin, size, radius = 36, 160, 20
    total = size + margin * 2
    ring = Image.new("RGBA", (total, total), (0, 0, 0, 0))
    inner = rounded((size, size), radius, None, (255, 255, 255, 255), 4)
    ring.alpha_composite(inner, (margin, margin))
    alpha = ring.split()[3]
    glow_green = alpha.filter(ImageFilter.GaussianBlur(9)).point(lambda v: min(255, int(v * 2.2)))
    glow_cyan = alpha.filter(ImageFilter.GaussianBlur(20)).point(lambda v: min(255, int(v * 1.1)))
    out = Image.new("RGBA", (total, total), CYAN + (0,))
    out.putalpha(glow_cyan.point(lambda v: int(v * 0.45)))
    green = Image.new("RGBA", (total, total), GREEN + (0,))
    green.putalpha(glow_green.point(lambda v: int(v * 0.75)))
    out.alpha_composite(green)
    solid = Image.new("RGBA", (total, total), GREEN + (0,))
    solid.putalpha(alpha)
    out.alpha_composite(solid)
    c = margin + radius + 6
    nine_patch(out, (c, total - c), (c, total - c)).save(os.path.join(OUT, "focus.9.png"))


def focus_out():
    """Like focus.9.png, but the glow stays outside the ring, so text inside a
    focused guide programme stays clean: images/glow/focus-out.9.png."""
    margin, size, radius = 36, 160, 20
    total = size + margin * 2
    ring = Image.new("RGBA", (total, total), (0, 0, 0, 0))
    ring.alpha_composite(rounded((size, size), radius, None, (255, 255, 255, 255), 4), (margin, margin))
    alpha = ring.split()[3]
    inside = Image.new("L", (total, total), 0)
    inside.paste(rounded((size - 4, size - 4), radius - 2, (255, 255, 255, 255)).split()[3], (margin + 2, margin + 2))
    from PIL import ImageChops
    outside = ImageChops.invert(inside)
    glow_green = ImageChops.multiply(alpha.filter(ImageFilter.GaussianBlur(9)).point(lambda v: min(255, int(v * 2.2))), outside)
    glow_cyan = ImageChops.multiply(alpha.filter(ImageFilter.GaussianBlur(20)).point(lambda v: min(255, int(v * 1.1))), outside)
    out = Image.new("RGBA", (total, total), CYAN + (0,))
    out.putalpha(glow_cyan.point(lambda v: int(v * 0.45)))
    green = Image.new("RGBA", (total, total), GREEN + (0,))
    green.putalpha(glow_green.point(lambda v: int(v * 0.75)))
    out.alpha_composite(green)
    solid = Image.new("RGBA", (total, total), GREEN + (0,))
    solid.putalpha(alpha)
    out.alpha_composite(solid)
    c = margin + radius + 6
    nine_patch(out, (c, total - c), (c, total - c)).save(os.path.join(OUT, "focus-out.9.png"))


def pill():
    img = rounded((60, 52), 26, (255, 255, 255, 255))
    nine_patch(img, (27, 33), (25, 27)).save(os.path.join(OUT, "chip.9.png"))
    # A small dot (the LIVE light).
    dot = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse([0, 0, 63, 63], fill=(255, 77, 94, 255))
    dot.resize((16, 16), Image.LANCZOS).save(os.path.join(OUT, "live-dot.png"))


def guide_art():
    """Guide pieces: preview-ring.9.png (cyan frame with a soft glow, 36 px
    margin), progress.png (cyan-to-green bar), now-glow.png (the now line's halo)."""
    margin, size, radius = 36, 160, 20
    total = size + margin * 2
    ring = Image.new("RGBA", (total, total), (0, 0, 0, 0))
    ring.alpha_composite(rounded((size, size), radius, None, (255, 255, 255, 255), 2), (margin, margin))
    alpha = ring.split()[3]
    out = Image.new("RGBA", (total, total), CYAN + (0,))
    out.putalpha(alpha.filter(ImageFilter.GaussianBlur(14)).point(lambda v: min(255, int(v * 1.3))))
    line = Image.new("RGBA", (total, total), CYAN + (0,))
    line.putalpha(alpha.point(lambda v: int(v * 0.55)))
    out.alpha_composite(line)
    c = margin + radius + 6
    nine_patch(out, (c, total - c), (c, total - c)).save(os.path.join(OUT, "preview-ring.9.png"))

    bar = Image.new("RGBA", (512, 8), (0, 0, 0, 0))
    for x in range(512):
        p = x / 511
        bar.paste(tuple(int(CYAN[i] + (GREEN[i] - CYAN[i]) * p) for i in range(3)) + (255,), (x, 0, x + 1, 8))
    bar.save(os.path.join(OUT, "progress.png"))

    halo = Image.new("L", (40, 8), 0)
    ImageDraw.Draw(halo).rectangle([18, 0, 21, 7], fill=255)
    halo = halo.filter(ImageFilter.GaussianBlur(5)).point(lambda v: min(255, int(v * 2.4)))
    glow = Image.new("RGBA", (40, 8), CYAN + (0,))
    glow.putalpha(halo)
    glow.save(os.path.join(OUT, "now-glow.png"))


def logo():
    """The ring-and-slash mark, then zer (white) Ø (green) TV (cyan); 1080p height 60."""
    scale = 4
    h = 60
    font = ImageFont.truetype(BOLD, 40 * scale)
    parts = [("zer", (255, 255, 255)), ("Ø", GREEN), (" ", None), ("TV", CYAN)]
    probe = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    widths = [probe.textlength(t, font=font) for t, _ in parts]
    mark = 46 * scale
    gap = 16 * scale
    w = int(mark + gap + sum(widths)) + 8 * scale
    img = Image.new("RGBA", (w, h * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top = (h * scale - mark) // 2
    stroke = 5 * scale
    d.ellipse([stroke // 2, top + stroke // 2, mark - stroke // 2, top + mark - stroke // 2], outline=GREEN, width=stroke)
    pad = int(mark * 0.25)
    d.line([(pad, top + mark - pad), (mark - pad, top + pad)], fill=GREEN, width=stroke)
    x = mark + gap
    box = probe.textbbox((0, 0), "zerØTV", font=font)
    y = (h * scale - (box[3] - box[1])) // 2 - box[1]
    for (text, color), tw in zip(parts, widths):
        if color:
            d.text((x, y), text, font=font, fill=color)
        x += tw
    # A soft glow under the green parts.
    alpha = img.split()[3].filter(ImageFilter.GaussianBlur(6 * scale)).point(lambda v: int(v * 0.35))
    glow = Image.new("RGBA", img.size, GREEN + (0,))
    glow.putalpha(alpha)
    glow.alpha_composite(img)
    glow.resize((w // scale, h), Image.LANCZOS).save(os.path.join(OUT, "logo.png"))


def star_points(cx, cy, outer, inner):
    import math
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = outer if i % 2 == 0 else inner
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def tile_icons():
    """Country-grid pictures: fav.png (Favorites), recent.png (Recently Watched),
    world.png (a group with no flag), pin.png (the pinned badge)."""
    s = 4
    size = 180

    def save(img, name, out_size):
        img.resize(out_size, Image.LANCZOS).save(os.path.join(OUT, name))

    img = Image.new("RGBA", (size * s, size * s), (0, 0, 0, 0))
    ImageDraw.Draw(img).polygon(star_points(size * s / 2, size * s * 0.53, size * s * 0.46, size * s * 0.19), fill=GREEN + (255,))
    save(img, "fav.png", (size, size))

    img = Image.new("RGBA", (size * s, size * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = 12 * s
    d.ellipse([w, w, size * s - w, size * s - w], outline=CYAN + (255,), width=w)
    c = size * s / 2
    d.line([(c, c), (c, size * s * 0.25)], fill=CYAN + (255,), width=w)
    d.line([(c, c), (size * s * 0.70, c)], fill=CYAN + (255,), width=w)
    d.ellipse([c - w, c - w, c + w, c + w], fill=CYAN + (255,))
    save(img, "recent.png", (size, size))

    img = Image.new("RGBA", (size * s, size * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = 9 * s
    m = w
    col = (131, 145, 170, 255)
    d.ellipse([m, m, size * s - m, size * s - m], outline=col, width=w)
    d.ellipse([size * s * 0.30, m, size * s * 0.70, size * s - m], outline=col, width=w)
    d.line([(m, c), (size * s - m, c)], fill=col, width=w)
    d.line([(size * s * 0.12, size * s * 0.30), (size * s * 0.88, size * s * 0.30)], fill=col, width=w)
    d.line([(size * s * 0.12, size * s * 0.70), (size * s * 0.88, size * s * 0.70)], fill=col, width=w)
    save(img, "world.png", (size, size))

    p = 40
    img = Image.new("RGBA", (p * s, p * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, p * s - 1, p * s - 1], fill=(7, 11, 18, 230))
    d.polygon(star_points(p * s / 2, p * s * 0.53, p * s * 0.36, p * s * 0.15), fill=GREEN + (255,))
    save(img, "pin.png", (p, p))


def manifest_version():
    import re
    text = open(os.path.join(ROOT, "manifest"), encoding="utf-8").read()
    return ".".join(re.search(k + r"_version=(\d+)", text).group(1) for k in ("major", "minor", "build"))


def neon_scene(w0, h0, horizon_at, mark, word=None, bar=None, slogan=None, version=None, stars=140, s=2):
    """The zer0TV neon-horizon picture (splash and app icons): a grid floor
    running to a lit horizon, the zerØ mark as a glowing neon tube, and
    optionally the name, a cyan-to-green light bar, the slogan and the version.
    Sizes are in the picture's own pixels; k scales the glows (1 = 1080 tall)."""
    import math
    import random
    from PIL import ImageChops
    k = h0 / 1080
    w, h = w0 * s, h0 * s
    cx = w // 2
    horizon = int(h * horizon_at)

    def px(v):
        return int(v * s)

    def layer():
        return Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def glow_of(src, color, radius, strength):
        g = Image.new("RGBA", (w, h), color + (0,))
        g.putalpha(src.split()[3].filter(ImageFilter.GaussianBlur(max(1, radius))).point(lambda v: min(255, int(v * strength))))
        return g

    # Sky: deep ground, a cyan haze high on the left, green low on the right.
    img = Image.new("RGBA", (w, h), GROUND + (255,))
    for center, radii, color, strength in [
        ((int(w * 0.22), int(h * 0.05)), (int(w * 0.55), int(h * 0.55)), CYAN, 0.16),
        ((int(w * 0.85), int(h * 0.45)), (int(w * 0.45), int(h * 0.40)), GREEN, 0.08),
    ]:
        tint, mask = radial((w, h), center, radii, color, strength)
        img = Image.composite(tint.convert("RGBA"), img, mask)

    # Faint stars above the horizon.
    rnd = random.Random(7)
    sky = layer()
    d = ImageDraw.Draw(sky)
    for _ in range(stars):
        x, y = rnd.randrange(w), rnd.randrange(int(horizon * 0.92))
        r = max(1, int(rnd.choice([1, 1, 1, 2]) * s * max(k, 0.5)))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 235, 255, rnd.randrange(40, 150)))
    img.alpha_composite(sky)

    # Horizon: a bright line with a wide soft bloom.
    bloom = layer()
    ImageDraw.Draw(bloom).rectangle([0, horizon - px(2 * k + 0.5), w, horizon + px(2 * k + 0.5)], fill=CYAN + (255,))
    img.alpha_composite(glow_of(bloom, CYAN, px(60 * k), 0.9))
    img.alpha_composite(glow_of(bloom, GREEN, px(14 * k), 0.6))

    # Grid floor: lines fanning from the vanishing point, cross lines bunching
    # towards the horizon; brighter near the viewer, dimmer at the sides.
    grid = layer()
    d = ImageDraw.Draw(grid)
    line_w = max(2, px(3 * k))
    for i in range(-26, 27):
        x_bottom = cx + i * int(w * 0.075)
        d.line([(cx + (x_bottom - cx) * 0.04, horizon), (x_bottom, h)], fill=CYAN + (255,), width=line_w)
    for n in range(1, 12):
        depth = (n / 11) ** 2.1
        y = int(horizon + (h - horizon) * depth)
        d.line([(0, y), (w, y)], fill=CYAN + (255,), width=max(2, int(line_w * (0.4 + depth))))
    fade = Image.new("L", (w, h), 0)
    fd = ImageDraw.Draw(fade)
    for y in range(horizon, h):
        fd.line([(0, y), (w, y)], fill=int(25 + 150 * (y - horizon) / max(1, h - horizon)))
    side = Image.new("L", (w, h), 0)
    ImageDraw.Draw(side).ellipse([-w * 0.15, horizon - h * 0.3, w * 1.15, h * 1.6], fill=255)
    side = side.filter(ImageFilter.GaussianBlur(px(120 * k)))
    grid.putalpha(ImageChops.multiply(grid.split()[3], ImageChops.multiply(fade, side)))
    img.alpha_composite(glow_of(grid, CYAN, px(8 * k), 1.4))
    img.alpha_composite(grid)

    # The mark: a neon tube (white-hot core, green body, wide green bloom).
    my, mr, body_w, core_w = (px(v) for v in mark)
    off = int(mr * 0.66)

    def draw_mark(width, color):
        m = layer()
        md = ImageDraw.Draw(m)
        md.ellipse([cx - mr, my - mr, cx + mr, my + mr], outline=color, width=width)
        md.line([(cx - off, my + off), (cx + off, my - off)], fill=color, width=width)
        return m

    body = draw_mark(body_w, GREEN + (255,))
    img.alpha_composite(glow_of(body, GREEN, mr // 2, 0.55))
    img.alpha_composite(glow_of(body, GREEN, mr // 6, 1.0))
    img.alpha_composite(body)
    img.alpha_composite(draw_mark(max(1, core_w), (225, 255, 215, 255)))

    probe = ImageDraw.Draw(layer())
    if word:
        # zerØ TV, with its own soft glow.
        font = ImageFont.truetype(BOLD, px(word[1]))
        parts = [("zer", (255, 255, 255)), ("Ø", GREEN), (" TV", CYAN)]
        widths = [probe.textlength(t_, font=font) for t_, _ in parts]
        top = probe.textbbox((0, 0), "zerØTV", font=font)[1]
        text = layer()
        td = ImageDraw.Draw(text)
        x = cx - sum(widths) / 2
        for (part, color), tw in zip(parts, widths):
            td.text((x, px(word[0]) - top), part, font=font, fill=color + (255,))
            x += tw
        img.alpha_composite(glow_of(text, CYAN, px(word[1] * 0.23), 0.45))
        img.alpha_composite(text)

    if bar:
        # Light bar: cyan to green, bright in the middle.
        strip = layer()
        bw, by, bh = px(bar[1]), px(bar[0]), max(2, px(4 * k))
        for i in range(bw):
            p = i / (bw - 1)
            col = tuple(int(CYAN[c] + (GREEN[c] - CYAN[c]) * p) for c in range(3))
            strip.paste(col + (int(255 * math.sin(math.pi * p) ** 0.6),), (cx - bw // 2 + i, by, cx - bw // 2 + i + 1, by + bh))
        img.alpha_composite(glow_of(strip, CYAN, px(12 * k), 1.2))
        img.alpha_composite(strip)

    d = ImageDraw.Draw(img)
    if slogan:
        # The slogan, spaced out in capitals.
        font = ImageFont.truetype(BOLD, px(slogan[1]))
        spacing = px(slogan[2])
        letters = [(ch, probe.textlength(ch, font=font)) for ch in "TUNE IN  ·  TURN ON  ·  DROP OUT"]
        x = cx - (sum(lw for _, lw in letters) + spacing * (len(letters) - 1)) / 2
        for ch, lw in letters:
            d.text((x, px(slogan[0])), ch, font=font, fill=(195, 205, 222, 255))
            x += lw + spacing

    if version:
        font = ImageFont.truetype(BOLD, px(28 * k))
        label = "v" + version
        d.text((w - px(56 * k) - d.textlength(label, font=font), h - px(70 * k)), label, font=font, fill=(131, 145, 170, 255))

    # Vignette.
    inner = Image.new("L", (w, h), 0)
    ImageDraw.Draw(inner).ellipse([-w * 0.1, -h * 0.25, w * 1.1, h * 1.25], fill=255)
    inner = inner.filter(ImageFilter.GaussianBlur(px(160 * k)))
    dark = Image.new("RGBA", (w, h), (2, 4, 8, 0))
    dark.putalpha(ImageChops.invert(inner).point(lambda v: int(v * 0.75)))
    img.alpha_composite(dark)
    return img.convert("RGB").resize((w0, h0), Image.LANCZOS)


def splash(version):
    """The launch splash with the manifest's version (JPEG keeps the package
    small): images/splash_fhd.jpg (1920x1080) and images/splash_hd.jpg (1280x720)."""
    img = neon_scene(1920, 1080, 0.75, mark=(270, 140, 22, 7), word=(470, 132), bar=(648, 560),
                     slogan=(684, 34, 9), version=version)
    img.save(os.path.join(ROOT, "images", "splash_fhd.jpg"), quality=92)
    img.resize((1280, 720), Image.LANCZOS).save(os.path.join(ROOT, "images", "splash_hd.jpg"), quality=92)


def app_icons():
    """Roku home-screen icons in the splash's look: icon_focus_fhd.png
    (540x405), icon_focus_hd.png (290x218), icon_side_hd.png (108x69); and the
    README's assets/icon.png (the same tile as the home screen)."""
    big = neon_scene(540, 405, 0.80, mark=(138, 82, 14, 4), word=(246, 64), bar=(300, 230), stars=40, s=4)
    big.save(os.path.join(ROOT, "images", "icon_focus_fhd.png"), optimize=True)
    big.save(os.path.join(ROOT, "assets", "icon.png"), optimize=True)
    neon_scene(290, 218, 0.80, mark=(74, 44, 8, 2), word=(132, 35), bar=(161, 124), stars=20, s=6) \
        .save(os.path.join(ROOT, "images", "icon_focus_hd.png"), optimize=True)
    neon_scene(108, 69, 0.82, mark=(30, 21, 4, 1), stars=6, s=8) \
        .save(os.path.join(ROOT, "images", "icon_side_hd.png"), optimize=True)


def main():
    import sys
    if "--splash" in sys.argv:
        # Only the splash (package.py runs this on every build).
        splash(manifest_version())
        print("splash v" + manifest_version())
        return
    os.makedirs(OUT, exist_ok=True)
    background()
    card()
    focus()
    pill()
    logo()
    tile_icons()
    guide_art()
    focus_out()
    app_icons()
    for name in sorted(os.listdir(OUT)):
        print(os.path.join(OUT, name), os.path.getsize(os.path.join(OUT, name)))


if __name__ == "__main__":
    main()
