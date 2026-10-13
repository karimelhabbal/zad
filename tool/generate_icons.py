"""Generates Zad's Android launcher icons and native-splash artwork.

The artwork is **derived from the approved Stitch brand asset** rather than
redrawn, so the shipped icon is pixel-faithful to the design:

    stitch_zad_islamic_mobile_app/minimal_zad_icon/screen.png

That asset is a 1024x1024 RGBA image: a deep-emerald squircle (field
`#0F4331`, spanning x/y 48..975) carrying a faint gold hairline frame and a
brushed-gold emblem — a Khatam (two overlapping squares), an inner circle and
the abstract "زاد" crescent-and-alef monogram — inside a 244..778 bounding box.

Three outputs are produced:

* `mipmap-*/ic_launcher.png` — the artwork verbatim (frame included). Used on
  API < 26 and by non-adaptive launchers, where nothing is masked.
* `mipmap-*/ic_launcher_foreground.png` — the gold mark alone on transparency,
  sized so it reads at the design's proportion inside the 72dp visible circle.
  The hairline frame is deliberately dropped here: it sits at 86% of the
  canvas, which every non-squircle launcher mask would clip into a broken
  partial ring.
* `drawable-*/splash_logo.png` — the gold mark alone, for the native launch
  screen, where it sits on the emerald gradient.

Run from the project root:

    <venv>/Scripts/python.exe tool/generate_icons.py

Everything it writes lands in `android/app/src/main/res/`; nothing else in the
project is touched.
"""

from __future__ import annotations

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
SOURCE = os.path.join(
    ROOT,
    "stitch_zad_islamic_mobile_app",
    "stitch_zad_islamic_mobile_app",
    "minimal_zad_icon",
    "screen.png",
)

# Measured from the artwork; also written to res/values/colors.xml.
FIELD = (15, 67, 49)  # #0F4331

# (r - b) discriminates gold from the emerald field cleanly: the field measures
# -39..-28, the mark +40..+139, with only a thin antialiased band between.
RB_FLOOR = 25
RB_CEIL = 60

LAUNCHER_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive-icon foreground: 108dp canvas, 66dp guaranteed safe zone.
ADAPTIVE_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

SPLASH_SIZES = {
    "drawable-mdpi": 144,
    "drawable-hdpi": 216,
    "drawable-xhdpi": 288,
    "drawable-xxhdpi": 432,
    "drawable-xxxhdpi": 576,
}

# The mark occupies 52.1% of the artwork; the splash renders it a touch larger.
SPLASH_FILL = 0.80

# Android crops the 108dp adaptive layer down to a 72dp visible circle, so a
# mark filling `ADAPTIVE_FILL` of the layer reads as `ADAPTIVE_FILL * 108 / 72`
# of what the user actually sees. The design puts the mark at 57.5% of its
# squircle — equivalent to 0.383 of the layer — and 0.40 holds that proportion
# while buying a little legibility at 48px.
ADAPTIVE_FILL = 0.40


def load_artwork() -> Image.Image:
    if not os.path.exists(SOURCE):
        raise SystemExit(f"missing source artwork: {SOURCE}")
    return Image.open(SOURCE).convert("RGBA")


def extract_mark(artwork: Image.Image) -> Image.Image:
    """Lifts the gold mark off the emerald field onto transparency.

    Alpha comes from an (r - b) ramp, and the colour is then unmixed against
    the known field colour so antialiased edges do not keep a green cast.
    """
    width, height = artwork.size
    src = artwork.load()
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dst = out.load()
    span = float(RB_CEIL - RB_FLOOR)

    for y in range(height):
        for x in range(width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            coverage = (r - b - RB_FLOOR) / span
            if coverage <= 0.0:
                continue
            if coverage > 1.0:
                coverage = 1.0
            alpha = coverage * (a / 255.0)

            # Unmix: observed = alpha * fg + (1 - alpha) * field.
            if coverage < 1.0:
                inv = 1.0 - coverage
                r = min(255, max(0, round((r - inv * FIELD[0]) / coverage)))
                g = min(255, max(0, round((g - inv * FIELD[1]) / coverage)))
                b = min(255, max(0, round((b - inv * FIELD[2]) / coverage)))

            dst[x, y] = (r, g, b, round(alpha * 255))

    return out


def make_launcher_icon(artwork: Image.Image, size: int) -> Image.Image:
    """The artwork verbatim, downscaled. Nothing is masked on API < 26."""
    return artwork.resize((size, size), Image.Resampling.LANCZOS)


def make_adaptive_foreground(mark: Image.Image, size: int) -> Image.Image:
    """The mark centred on a transparent 108dp canvas.

    Sized so the mark's bounding box is `ADAPTIVE_FILL` of the layer. Its
    outermost points reach `ADAPTIVE_FILL / 2 * 108` ≈ 21.6dp from the centre —
    inside both the 36dp visible radius and the guaranteed 33dp safe-zone
    radius — so no launcher mask clips it.
    """
    box = mark.getbbox()
    if box is None:
        raise SystemExit("extracted mark is empty — check the (r-b) thresholds")
    cropped = mark.crop(box)
    target = max(1, round(ADAPTIVE_FILL * size))
    scale = target / max(cropped.width, cropped.height)
    fitted = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(
        fitted,
        ((size - fitted.width) // 2, (size - fitted.height) // 2),
        fitted,
    )
    return canvas


def make_splash_mark(mark: Image.Image, size: int) -> Image.Image:
    """The mark, cropped to its bounds and enlarged for the launch screen."""
    box = mark.getbbox()
    if box is None:
        raise SystemExit("extracted mark is empty — check the (r-b) thresholds")
    cropped = mark.crop(box)
    target = max(1, round(size * SPLASH_FILL))
    scale = target / max(cropped.width, cropped.height)
    fitted = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(
        fitted,
        ((size - fitted.width) // 2, (size - fitted.height) // 2),
        fitted,
    )
    return canvas


def _write(img: Image.Image, folder: str, name: str) -> None:
    target = os.path.join(RES, folder)
    os.makedirs(target, exist_ok=True)
    img.save(os.path.join(target, name), "PNG", optimize=True)


def main() -> int:
    artwork = load_artwork()
    mark = extract_mark(artwork)
    if mark.getbbox() is None:
        print("extraction produced nothing", file=sys.stderr)
        return 1

    written = 0
    for folder, size in LAUNCHER_SIZES.items():
        _write(make_launcher_icon(artwork, size), folder, "ic_launcher.png")
        written += 1
    for folder, size in ADAPTIVE_SIZES.items():
        _write(make_adaptive_foreground(mark, size), folder, "ic_launcher_foreground.png")
        written += 1
    for folder, size in SPLASH_SIZES.items():
        _write(make_splash_mark(mark, size), folder, "splash_logo.png")
        written += 1

    print(f"mark bbox: {mark.getbbox()} of {mark.size}")
    print(f"wrote {written} PNGs into {RES}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
