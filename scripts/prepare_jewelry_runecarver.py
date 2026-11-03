"""Prepare the selected grey-metal Runecarver housing without loading addon code.

The original pinned sheet is supplied with --source; its source, atlas members
and redistribution boundaries are recorded in third_party/Jewelry-ARTWORK.md.
The original 128-square grey cell is shared by empty and equipped slots.
"""

import argparse
import hashlib
import math
from pathlib import Path
import struct

from PIL import Image, ImageOps

from prepare_client_textures import blp_bgra_levels


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "8df6e6c889eda1e100b9550762b573a647730b0435a6702ae194b55b830f124c"
FRAME_RECT = (451, 1135, 899, 1589)
GLOW_RECT = (1, 1135, 449, 1589)
SOURCE_SATURATION = 0.05


def runtime_housing(path, housing):
    """Keep the original housing and clear the retired brightness/glow cell."""
    data = bytearray(path.read_bytes())
    width, height, levels = blp_bgra_levels(data)
    if (width, height) != (512, 128) or data[8] != 3 or len(levels) != 1:
        raise ValueError("Expected the existing single-level Raw3 jewelry atlas")
    offset = struct.unpack_from("<I", data, 20)[0]
    stride = 128 * 4
    for left, image in ((256, housing), (384, Image.new("RGBA", (128, 128)))):
        pixels = image.tobytes("raw", "BGRA")
        for row in range(128):
            start = offset + (row * width + left) * 4
            data[start:start + stride] = pixels[row * stride:(row + 1) * stride]
    return bytes(data)


def prepare(source, output, runtime=None):
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
    # Preserve the original grey input byte-for-byte for every equipment state.
    if output.exists():
        with Image.open(output) as retained:
            if retained.size != canvas.size or retained.convert("RGBA").tobytes() != canvas.tobytes():
                raise ValueError("Housing preparation must preserve the original input")
    runtime_data = runtime_housing(runtime, canvas) if runtime else None
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists():
        canvas.save(output, compression=None)
    if runtime is not None:
        runtime.write_bytes(runtime_data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/Runecarver.tga")
    parser.add_argument("--runtime", type=Path, help="Refresh the shared original housing and clear its retired variant")
    options = parser.parse_args()
    prepare(options.source, options.output, options.runtime)
