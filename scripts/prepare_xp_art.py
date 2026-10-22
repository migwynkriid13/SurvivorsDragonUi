"""Extend the existing action-bar side walls for its joined XP channel.

This prepares texture pixels only. It never loads addon or game code.
"""

import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def prepare(source, output):
    original = Image.open(source).convert("RGBA")
    # The source has two pixels per vertical UI unit. Insert eight UI units
    # before the lower chamfers, repeating the last straight side-wall row.
    # Everything above and below the insertion retains its original pixels.
    shell = Image.new("RGBA", (512, 256))
    shell.paste(original.crop((0, 0, 512, 92)), (0, 0))
    row = original.crop((0, 91, 512, 92))
    for y in range(92, 108):
        shell.paste(row, (0, y))
    shell.paste(original.crop((0, 92, 512, 128)), (0, 108))
    output.parent.mkdir(parents=True, exist_ok=True)
    shell.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "media/tex/actionbars/HDActionBar.tga")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/actionbars/HDActionBarXP.tga")
    args = parser.parse_args()
    prepare(args.source, args.output)
