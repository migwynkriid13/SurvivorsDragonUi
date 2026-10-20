"""Copy the selected gold bezel and draw an original stored-level count badge.

This prepares artwork only, without loading or executing addon code. Supply
the isolated IconFrameGold.tga from the source pinned in LevelUp-ARTWORK.md.
"""

import argparse
from pathlib import Path
from shutil import copyfile

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


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


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/levelup")
    options = parser.parse_args()
    prepare(options.source, options.output)
