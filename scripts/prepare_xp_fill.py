"""Reduce the original XP fill's overall fading by thirty percent.

Only image data is prepared; no addon or game code is loaded or executed.
"""

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def prepare(source, output):
    original = Image.open(source).convert("RGBA")
    # Construct an opaque reference with the original bevel and rounded ends.
    profile = original.crop((384, 0, 385, 16))
    uniform = profile.resize((512, 16), Image.Resampling.NEAREST)
    uniform.putalpha(255)
    # Keep only the original rounded outline's antialiasing at each end.
    # Normalize away the source's vertical transparency; the body stays opaque.
    for y in range(16):
        interior_alpha = profile.getpixel((0, y))[3]
        for x in list(range(6)) + list(range(506, 512)):
            color = uniform.getpixel((x, y))
            edge_alpha = min(255, round(original.getpixel((x, y))[3] * 255 / interior_alpha))
            uniform.putpixel((x, y), color[:3] + (edge_alpha,))
    # Keep 70% of the original RGB shading and alpha fading. The remaining 30%
    # comes from the opaque reference; both share the original rounded outline.
    softened = Image.blend(original, uniform, 0.3)
    # Soften only the leading outline: at most 18% extra transparency, fading
    # smoothly to zero over the first 12 source columns. Keep all RGB intact.
    for x in range(12):
        opacity = 1 - 0.18 * (1 - x / 12) ** 2
        for y in range(16):
            color = softened.getpixel((x, y))
            softened.putpixel((x, y), color[:3] + (round(color[3] * opacity),))
    output.parent.mkdir(parents=True, exist_ok=True)
    softened.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "media/tex/xprep/main.tga")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/xprep/main_soft.tga")
    args = parser.parse_args()
    prepare(args.source, args.output)
