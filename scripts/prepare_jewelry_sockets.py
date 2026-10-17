"""Prepare one continuous socket rail above the original bar artwork.

Only texture pixels are read. No addon or game code is loaded or executed.
The native reference uses 36-unit buttons and six-unit gaps. The rail replaces
only the 12-unit top strip and extends it around five sockets. The remainder
of HDActionBar stays intact.
"""

import argparse
import math
from pathlib import Path

from PIL import Image

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
    # Native profile row 30 falls at cap y=33.5 after the original 26-unit
    # offset. Sampling that same phase preserves every horizontal bevel row,
    # including its translucent outer pixels, at the two 90-degree joins.
    baseline = 33.5
    radius, center, opening = 20, 20, 13.7
    junction = math.sqrt(radius * radius - (baseline - center) ** 2)
    left_join, right_join = center - junction, center + junction
    pixels = rail.load()
    for index in range(5):
        start = (46 + index * 42) * SCALE
        for py in range(rail.height):
            y = (py + 0.5) / SCALE
            for px in range(40 * SCALE):
                x = (px + 0.5) / SCALE
                radial = math.hypot(x - center, y - center)
                if radial < opening:
                    pixels[start + px, py] = (0, 0, 0, 0)
                    continue
                if radial > radius and y < baseline:
                    continue
                if y >= baseline and (x <= left_join or x >= right_join):
                    # Straight feet and gaps use the same untouched native rows.
                    continue
                # Distance to the actual outer boundary of circle union bar:
                # its surviving circular arc, two join points and flat edges.
                distance = min(
                    math.hypot(x - left_join, y - baseline),
                    math.hypot(x - right_join, y - baseline),
                )
                if radial > 0 and center + radius * (y - center) / radial <= baseline:
                    distance = min(distance, abs(radius - radial))
                if x <= left_join or x >= right_join:
                    distance = min(distance, abs(y - baseline))
                source_y = min(48, 30 + math.floor(distance * SCALE))
                # The formed socket interior uses the original bar material;
                # only its circular opening is clear. No extra inner line is drawn.
                color = native.getpixel((start + px, source_y))
                if py >= rail.height - SCALE:
                    # Meet the unchanged lower background at its original row.
                    original = native.getpixel((start + px, py - 26 * SCALE))
                    blend = (py - (rail.height - SCALE) + 1) / SCALE
                    color = tuple(round(a * (1 - blend) + b * blend) for a, b in zip(color, original))
                pixels[start + px, py] = color
    atlas = Image.new("RGBA", (2048, 256))
    atlas.alpha_composite(rail)
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bar", type=Path, default=ROOT / "media/tex/actionbars/HDActionBar.tga")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/SocketRail.tga")
    args = parser.parse_args()
    prepare(args.bar, args.output)
