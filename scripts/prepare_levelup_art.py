"""Prepare the gold bezel, count badge, translucent backdrop and soft gold glow.

This prepares artwork only, without loading or executing addon code. Supply
the isolated IconFrameGold.tga from the source pinned in LevelUp-ARTWORK.md.
"""

import argparse
import math
from pathlib import Path
from shutil import copyfile

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def prepare_backdrop(output):
    width, height = 512, 128
    backdrop = Image.new("RGBA", (width, height))
    glow = Image.new("RGBA", (width, height))
    dark_pixels, glow_pixels = backdrop.load(), glow.load()
    for y in range(height):
        for x in range(width):
            # Rounded-rectangle signed distance, inset eight pixels so the
            # feathered halo stays within the existing click/edit bounds.
            qx = abs(x + 0.5 - width / 2) - (width / 2 - 28)
            qy = abs(y + 0.5 - height / 2) - (height / 2 - 28)
            distance = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - 20
            coverage = max(0, min(1, 0.5 - distance / 12))
            shade = 0.54 + 0.14 * (1 - abs(y + 0.5 - height / 2) / (height / 2))
            dark_pixels[x, y] = (0, 0, 0, round(255 * shade * coverage))
            halo = math.exp(-0.5 * (distance / 4.5) ** 2)
            glow_pixels[x, y] = (242, 184, 73, round(255 * 0.72 * halo))
    backdrop.save(output / "Backdrop.tga", compression=None)
    glow.save(output / "Glow.tga", compression=None)


def prepare(source, output):
    output.mkdir(parents=True, exist_ok=True)
    copyfile(source, output / "IconFrameGold.tga")
    scale, size = 4, 64
    image = Image.new("RGBA", (size * scale, size * scale))
    draw = ImageDraw.Draw(image)
    draw.ellipse(
        (scale, scale, (size - 1) * scale, (size - 1) * scale),
        fill=(247, 209, 107, 255),
        outline=(110, 80, 34, 255),
        width=3 * scale,
    )
    image.resize((size, size), Image.Resampling.LANCZOS).save(output / "CountBadge.tga", compression=None)
    prepare_backdrop(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/levelup")
    options = parser.parse_args()
    prepare(options.source, options.output)
