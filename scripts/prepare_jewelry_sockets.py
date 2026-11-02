"""Prepare the original straight bar edge with clear jewelry openings.

Only texture pixels are read. No addon or game code is loaded or executed.
The native reference uses 36-unit buttons and six-unit gaps. The rail replaces
only the 12-unit top strip, without the retired circular socket surrounds.
The remainder of HDActionBar stays intact. Write the three legal runtime
strips directly, without leaving an intermediate atlas or detached-circle copy.
"""

import argparse
import math
from pathlib import Path

from PIL import Image

from prepare_client_textures import save_image

ROOT = Path(__file__).resolve().parents[1]
SCALE = 4


def prepare(bar_path, output):
    bar = Image.open(bar_path).convert("RGBA")
    half = bar.resize((150 * SCALE, 64 * SCALE), Image.Resampling.BILINEAR)
    native = Image.new("RGBA", (300 * SCALE, 64 * SCALE))
    native.alpha_composite(half)
    native.alpha_composite(half.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (150 * SCALE, 0))
    rail = Image.new("RGBA", (300 * SCALE, 38 * SCALE))
    rail.alpha_composite(native.crop((0, 0, 300 * SCALE, 12 * SCALE)), (0, 26 * SCALE))
    # Preserve the existing icon openings, including through the straight edge.
    # All pixels above the original strip stay clear: Runecarver owns the rim.
    center, opening = 20, 13.7
    pixels = rail.load()
    for index in range(5):
        start = (46 + index * 42) * SCALE
        for py in range(26 * SCALE, rail.height):
            y = (py + 0.5) / SCALE
            for px in range(40 * SCALE):
                x = (px + 0.5) / SCALE
                radial = math.hypot(x - center, y - center)
                if radial < opening:
                    pixels[start + px, py] = (0, 0, 0, 0)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Match the existing three 400-pixel spans and both neighbour gutters.
    for index in range(3):
        left = index * 400
        tile = Image.new("RGBA", (512, 256))
        tile.paste(rail.crop((left, 0, left + 400, rail.height)), (1, 0))
        neighbour = max(0, left - 1)
        tile.paste(rail.crop((neighbour, 0, neighbour + 1, rail.height)), (0, 0))
        # The original large atlas supplied clear padding after the final span.
        tile.paste(rail.crop((left + 400, 0, left + 401, rail.height)), (401, 0))
        path = output if index == 0 else output.with_stem(output.stem + "_" + str(index + 1))
        save_image(tile, path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bar", type=Path, default=ROOT / "media/tex/actionbars/HDActionBar.tga")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/SocketRail.blp")
    args = parser.parse_args()
    prepare(args.bar, args.output)
