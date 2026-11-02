"""Prepare the selected Artisan metal artwork without executing addon code.

Supply the professions chrome sheet pinned in third_party/LevelUp-ARTWORK.md.
Only prepared artwork is retained; the source sheet stays outside the project.
"""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

from prepare_client_textures import blp_from_bgra

ROOT = Path(__file__).resolve().parents[1]
TOP = (478, 431, 738, 531)
BOTTOM = (740, 431, 1000, 530)
SLOT = (405, 1643, 445, 1683)


def legacy_backdrops():
    """Recreate the original geometric art still used by other design previews."""
    width, height = 512, 128
    backdrop = Image.new("RGBA", (width, height))
    glow = Image.new("RGBA", (width, height))
    dark_pixels, glow_pixels = backdrop.load(), glow.load()
    for y in range(height):
        for x in range(width):
            qx = abs(x + 0.5 - width / 2) - (width / 2 - 28)
            qy = abs(y + 0.5 - height / 2) - (height / 2 - 28)
            distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - 20
            coverage = max(0, min(1, 0.5 - distance / 12))
            shade = 0.54 + 0.14 * (1 - abs(y + 0.5 - height / 2) / (height / 2))
            dark_pixels[x, y] = (0, 0, 0, round(255 * shade * coverage))
            halo = math.exp(-0.5 * (distance / 4.5) ** 2)
            glow_pixels[x, y] = (242, 184, 73, round(255 * 0.72 * halo))
    return backdrop, glow


def prepare(source, output):
    output.mkdir(parents=True, exist_ok=True)
    if source:
        original = Image.open(source).convert("RGBA")
        atlas = Image.new("RGBA", (512, 256))
        # Keep proposal 04's top/bottom 45-row caps. Five side-by-side strips
        # preserve both corners and the central crests at translated widths.
        top = original.crop(TOP)
        bottom = original.crop(BOTTOM)
        atlas.paste(top.crop((0, 0, 260, 45)), (0, 0))
        atlas.paste(bottom.crop((0, 54, 260, 99)), (0, 45))
        atlas.paste(original.crop(SLOT), (272, 0))
    else:
        # Rebuild only the halo from retained authoring pixels, without another
        # download or changing any of the original panel/rim pixels.
        atlas = Image.open(output / "Artisan.tga").convert("RGBA")

    panel = atlas.crop((0, 0, 260, 90))
    red, green, blue, alpha = panel.split()
    brightness = ImageChops.lighter(red, ImageChops.lighter(green, blue))
    # The dark interior does not emit light. Derive the luminous metal and
    # crests from their actual pixels, then soften in the same source space.
    mask = brightness.point(lambda value: round(max(0, value - 32) * 0.55))
    mask = ImageChops.multiply(mask, alpha).filter(ImageFilter.GaussianBlur(1))
    glow = Image.new("RGBA", panel.size, (205, 216, 221, 0))
    glow.putalpha(mask)
    atlas.paste((0, 0, 0, 0), (0, 128, 512, 256))
    atlas.paste(glow, (0, 128))
    atlas.save(output / "Artisan.tga", compression=None)
    (output / "Artisan.blp").write_bytes(
        blp_from_bgra(atlas.width, atlas.height, atlas.tobytes("raw", "BGRA"))
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Pinned source sheet; omit to refresh only the halo")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/levelup")
    options = parser.parse_args()
    prepare(options.source, options.output)
