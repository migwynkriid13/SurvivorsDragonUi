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
    # and alpha profile while removing horizontal darkening and end-cap fading.
    profile = original.crop((384, 0, 385, 16))
    uniform = profile.resize((512, 16), Image.Resampling.NEAREST)
    output.parent.mkdir(parents=True, exist_ok=True)
    uniform.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "media/tex/xprep/main.tga")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/xprep/main_uniform.tga")
    args = parser.parse_args()
    prepare(args.source, args.output)
