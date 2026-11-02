"""Prepare the selected grey-metal Runecarver housing without loading addon code.

The original pinned sheet is supplied with --source; its source, atlas members
and redistribution boundaries are recorded in third_party/Jewelry-ARTWORK.md.
Only the prepared 128-square cell is retained as a project authoring input.
"""

import argparse
import hashlib
import math
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "8df6e6c889eda1e100b9550762b573a647730b0435a6702ae194b55b830f124c"
FRAME_RECT = (451, 1135, 899, 1589)
GLOW_RECT = (1, 1135, 449, 1589)
SOURCE_SATURATION = 0.05


def prepare(source, output):
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError("Use the pinned Shadowlands 9.0.5 Runecarving sheet")
    with Image.open(source) as original:
        sheet = original.convert("RGBA")
    frame = sheet.crop(FRAME_RECT)
    pixels = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            red, green, blue, alpha = pixels[x, y]
            radius = math.hypot(
                (x + 0.5 - frame.width / 2) / frame.width,
                (y + 0.5 - frame.height / 2) / frame.height,
            )
            coverage = max(0, min(1, (radius - 0.33) * min(frame.size) + 0.5))
            pixels[x, y] = (red, green, blue, round(alpha * coverage))
    glow = sheet.crop(GLOW_RECT).resize((124, 126), Image.Resampling.LANCZOS)
    glow.putalpha(glow.getchannel("A").point(lambda alpha: round(alpha * 0.32)))
    canvas = Image.new("RGBA", (128, 128))
    canvas.alpha_composite(glow, (2, 1))
    canvas.alpha_composite(frame.resize((118, 120), Image.Resampling.LANCZOS), (5, 4))
    # Match the neutral action-bar metal while retaining source shading/alpha.
    grey = ImageOps.grayscale(canvas).convert("RGBA")
    grey.putalpha(canvas.getchannel("A"))
    canvas = Image.blend(grey, canvas, SOURCE_SATURATION)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/Runecarver.tga")
    options = parser.parse_args()
    prepare(options.source, options.output)
