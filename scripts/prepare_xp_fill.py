"""Remove horizontal shading from the original XP fill using its native profile.

Only image data is prepared; no addon or game code is loaded or executed.
"""

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def prepare(source, output):
    original = Image.open(source).convert("RGBA")
    # Repeat one fully developed interior column, preserving its vertical bevel
    # while removing horizontal darkening. Full interior opacity
    # prevents the differently shaded shell from showing through the bevel.
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
    output.parent.mkdir(parents=True, exist_ok=True)
    uniform.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "media/tex/xprep/main.tga")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/xprep/main_uniform.tga")
    args = parser.parse_args()
    prepare(args.source, args.output)
