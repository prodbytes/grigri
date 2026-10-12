# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11", "numpy>=2"]
# ///
"""Make the app icon's PNGs from its source art (see specs/platforms.md).

Reads grigri_app/assets/icon/source.png (the grigri over mountains, on a
transparent background), clears the stray yellow pixels the artwork left in
its transparent areas, and writes, next to it:

- icon.png: the whole icon, 1024 px, on the theme's night background;
- icon-foreground.png: the emblem alone, 1024 px, transparent, sized to
  stay inside the circle Android's adaptive icon masks may cut.

Run from the repository root: uv run scripts/make-icon.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

ICON_DIR = Path(__file__).resolve().parent.parent / "grigri_app/assets/icon"
SIZE = 1024
NIGHT = (0x16, 0x1A, 0x16, 255)
# Share of the icon the emblem's widest side fills on iOS and the web.
FILL = 0.84
# Android shows a 72 dp circle of the 108 dp layer; keep inside its radius.
SAFE_RADIUS = SIZE * 0.36


def clean(art: Image.Image) -> Image.Image:
    a = np.array(art.convert("RGBA")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # Yellow (red and green high, little blue) isn't in the palette; the
    # grigri's orange has green well below red.
    yellow = (r > 150) & (g > 150) & (b < 140) & (r - g < 60)
    a[yellow, 3] = 0
    # Drop faint fringe left around the cleared pixels.
    a[a[..., 3] < 48, 3] = 0
    a[a[..., 3] == 0, :3] = 0
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def emblem(art: Image.Image) -> Image.Image:
    return art.crop(art.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox())


def place(img: Image.Image, scale: float, background) -> Image.Image:
    w, h = round(img.width * scale), round(img.height * scale)
    canvas = Image.new("RGBA", (SIZE, SIZE), background)
    canvas.alpha_composite(img.resize((w, h), Image.LANCZOS), ((SIZE - w) // 2, (SIZE - h) // 2))
    return canvas


def main() -> None:
    art = emblem(clean(Image.open(ICON_DIR / "source.png")))

    place(art, FILL * SIZE / max(art.size), NIGHT).convert("RGB").save(ICON_DIR / "icon.png", optimize=True)

    # The farthest opaque pixel from the centre sets the foreground's scale.
    alpha = np.array(art.getchannel("A"))
    ys, xs = np.nonzero(alpha > 128)
    reach = np.hypot(xs - art.width / 2, ys - art.height / 2).max()
    place(art, SAFE_RADIUS / reach, (0, 0, 0, 0)).save(ICON_DIR / "icon-foreground.png", optimize=True)


if __name__ == "__main__":
    main()
