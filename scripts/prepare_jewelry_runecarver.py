"""Prepare the selected grey-metal Runecarver housing without loading addon code.

The original pinned sheet is supplied with --source; its source, atlas members
and redistribution boundaries are recorded in third_party/Jewelry-ARTWORK.md.
The original 128-square grey cell is retained for empty slots. The selected
gemmed rarity cells can be built from that retained input with --rarity.
"""

import argparse
import hashlib
import math
from pathlib import Path
import struct

from PIL import Image, ImageDraw, ImageOps

from prepare_client_textures import blp_bgra_levels, save_image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "8df6e6c889eda1e100b9550762b573a647730b0435a6702ae194b55b830f124c"
FRAME_RECT = (451, 1135, 899, 1589)
GLOW_RECT = (1, 1135, 449, 1589)
SOURCE_SATURATION = 0.05
# Uncommon through legendary, in the order used by the runtime UVs.
GEM_PALETTES = (
    ("#57e734", "#d8ffbd", "#237212"),
    ("#278df4", "#c4e8ff", "#124878"),
    ("#b44df2", "#e8c4ff", "#522270"),
    ("#ff891e", "#ffe2b3", "#763909"),
)


def runtime_housing(path, housing):
    """Keep the original housing and clear the retired brightness cell."""
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


def gemmed_housing(housing, palette):
    """Bake the preview's halo behind the grey metal and its gems above."""
    color, light, dark = palette
    halo_rgb = tuple(round(channel + (255 - channel) * 0.07) for channel in bytes.fromhex(color[1:]))
    halo = Image.new("RGBA", (128, 128), (*halo_rgb, 0))
    pixels = halo.load()
    for y in range(128):
        for x in range(128):
            radius = math.hypot(x + 0.5 - 64, y + 0.5 - 64)
            progress = (radius - 44) / 17
            if progress <= 0.45:
                opacity = 114 - 16 * max(0, progress) / 0.45
            else:
                opacity = 98 * max(0, (1 - progress) / 0.55)
            # The runtime draws the composite above the item. Clear the halo
            # inside the icon's reach to match the mockup's behind-icon halo.
            opening = min(1, max(0, (radius - 42.6) / 0.8))
            pixels[x, y] = (*halo_rgb, round(opacity * opening * 1.2))
    frame = Image.alpha_composite(halo, housing)

    scale = 4
    gems = Image.new("RGBA", (128 * scale, 128 * scale))
    draw = ImageDraw.Draw(gems)
    for x, y, size in ((64, 17.5, 6.6), (21, 64, 3.55), (95, 34, 3.55), (95, 94, 3.55)):
        bezel = size + 1.1
        for points, fill, outline in (
            (((0, -bezel), (bezel, 0), (0, bezel), (-bezel, 0)), "#202229", "#777981"),
            (((0, -size), (size, 0), (0, size), (-size, 0)), color, None),
            (((0, -size), (-size, 0), (0.5, -0.4)), light, None),
            (((size, 0), (0, size), (0.5, -0.4)), dark, None),
        ):
            draw.polygon(
                [(round((x + dx) * scale), round((y + dy) * scale)) for dx, dy in points],
                fill=fill, outline=outline, width=scale,
            )
    return Image.alpha_composite(frame, gems.resize(frame.size, Image.Resampling.LANCZOS))


def rarity_atlas(housing, path):
    atlas = Image.new("RGBA", (512, 128))
    for index, palette in enumerate(GEM_PALETTES):
        atlas.paste(gemmed_housing(housing, palette), (index * 128, 0))
    save_image(atlas, path)


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
    # Preserve the original grey input byte-for-byte for the empty state.
    if output.exists():
        with Image.open(output) as retained:
            if retained.size != canvas.size or retained.convert("RGBA").tobytes() != canvas.tobytes():
                raise ValueError("Housing preparation must preserve the original input")
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists():
        canvas.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Prepare the neutral input from the pinned Blizzard sheet")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/Runecarver.tga")
    parser.add_argument("--runtime", type=Path, help="Refresh the shared neutral crop and clear the retired cell")
    parser.add_argument("--rarity", type=Path, help="Build the equipped gem and halo atlas")
    options = parser.parse_args()
    if not (options.source or options.runtime or options.rarity):
        parser.error("choose --source, --runtime or --rarity")
    if options.source:
        prepare(options.source, options.output)
    if options.runtime or options.rarity:
        with Image.open(options.output) as retained:
            housing = retained.convert("RGBA")
        if housing.size != (128, 128):
            raise ValueError("Expected the retained 128-square Runecarver input")
        if options.runtime:
            options.runtime.write_bytes(runtime_housing(options.runtime, housing))
        if options.rarity:
            rarity_atlas(housing, options.rarity)
