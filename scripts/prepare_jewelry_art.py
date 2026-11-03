"""Prepare jewelry rarity rims and the cold-lit housing.

Requires Pillow and a scratch source directory containing the pinned
bagborder2.blp listed in third_party/Jewelry-ARTWORK.md. The retained
Runecarver.tga input supplies only static housing artwork; item icons and labels
are never baked into it.
"""

import argparse
import math
from pathlib import Path

from PIL import Image

from prepare_client_textures import image_from_bytes
from prepare_jewelry_runecarver import SILVER_PALETTE, gemmed_housing

ROOT = Path(__file__).resolve().parents[1]


def rgba(path):
    return image_from_bytes(path.read_bytes())


def prepare_pet_rim(canvas):
    rim = canvas.crop((106, 56, 178, 128))
    pixels = rim.load()
    for y in range(72):
        for x in range(72):
            red, green, blue, alpha = pixels[x, y]
            radius = math.hypot(x + 0.5 - 36, y + 0.5 - 36)
            coverage = max(0, min(1, 35.5 - radius, radius - 26))
            pixels[x, y] = (red, green, blue, round(alpha * coverage))
    canvas.paste(rim, (576, 56))


def prepare(sources, output):
    ring = rgba(sources / "bagborder2.blp")
    canvas = Image.new("RGBA", (1024, 256))
    rim = ring.resize((86, 86), Image.Resampling.LANCZOS)
    for index in range(5):
        canvas.alpha_composite(rim, (98 + index * 88, 50))
    prepare_pet_rim(canvas)
    housing = rgba(ROOT / "media/tex/jewelry/Runecarver.tga")
    canvas.paste(housing, (896, 0))
    canvas.paste(gemmed_housing(housing, SILVER_PALETTE), (896, 128))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/Frame.tga")
    options = parser.parse_args()
    prepare(options.sources, options.output)
