"""Prepare the straight bar edge and short lower jewelry connectors.

Only texture pixels are read. No addon or game code is loaded or executed.
The native reference uses 36-unit buttons and six-unit gaps. The rail replaces
only the 12-unit top strip, retaining the bottom arch but no upper/side circle.
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


def connector_curve(join, baseline):
    """Start under the opaque housing and meet the bar with a flat tangent."""
    points = []
    for step in range(65):
        t = step / 64
        u = 1 - t
        points.append((
            6.5 * (1 - t ** 3) + join * t ** 3,
            26 * u ** 3 + 3 * 29.5 * u * u * t + 3 * baseline * u * t * t + baseline * t ** 3,
        ))
    return points


def segment_distance(x, y, first, last):
    dx, dy = last[0] - first[0], last[1] - first[1]
    along = max(0, min(1, ((x - first[0]) * dx + (y - first[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - first[0] - along * dx, y - first[1] - along * dy)


def prepare(bar_path, output):
    bar = Image.open(bar_path).convert("RGBA")
    half = bar.resize((150 * SCALE, 64 * SCALE), Image.Resampling.BILINEAR)
    native = Image.new("RGBA", (300 * SCALE, 64 * SCALE))
    native.alpha_composite(half)
    native.alpha_composite(half.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (150 * SCALE, 0))
    rail = Image.new("RGBA", (300 * SCALE, 38 * SCALE))
    rail.alpha_composite(native.crop((0, 0, 300 * SCALE, 12 * SCALE)), (0, 26 * SCALE))
    # Keep the native bar join and bevel phase. Narrow curved upper ends tuck
    # beneath the opaque housing instead of exposing a horizontal crop edge.
    center, radius, opening = 20, 20, 13.7
    baseline = 33.5
    junction = math.sqrt(radius * radius - (baseline - center) ** 2)
    left_join, right_join = center - junction, center + junction
    curve = connector_curve(left_join, baseline)
    segments = list(zip(curve, curve[1:]))
    # Geometry is shared by all five sockets; only native material pixels vary.
    geometry = []
    for py in range(26 * SCALE, rail.height):
        y = (py + 0.5) / SCALE
        edge = left_join
        if y < baseline:
            for first, last in segments:
                if first[1] <= y <= last[1]:
                    along = (y - first[1]) / (last[1] - first[1])
                    edge = first[0] + along * (last[0] - first[0])
                    break
        for px in range(40 * SCALE):
            x = (px + 0.5) / SCALE
            if math.hypot(x - center, y - center) < opening:
                geometry.append((px, py, None))
                continue
            if y < baseline and (x < edge or x > 40 - edge):
                continue
            distance = min(
                min(segment_distance(x, y, first, last) for first, last in segments),
                min(segment_distance(40 - x, y, first, last) for first, last in segments),
                math.hypot(x - min(x, left_join), y - baseline),
                math.hypot(x - max(x, right_join), y - baseline),
            )
            geometry.append((px, py, min(48, 30 + math.floor(distance * SCALE))))
    pixels = rail.load()
    for index in range(5):
        start = (46 + index * 42) * SCALE
        for px, py, source_y in geometry:
            if source_y is None:
                pixels[start + px, py] = (0, 0, 0, 0)
                continue
            color = native.getpixel((start + px, source_y))
            if py >= rail.height - SCALE:
                original = native.getpixel((start + px, py - 26 * SCALE))
                blend = (py - (rail.height - SCALE) + 1) / SCALE
                color = tuple(round(a * (1 - blend) + b * blend) for a, b in zip(color, original))
            pixels[start + px, py] = color
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
