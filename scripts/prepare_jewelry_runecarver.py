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

from prepare_client_textures import blp_bgra_levels, image_from_bytes, save_image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "8df6e6c889eda1e100b9550762b573a647730b0435a6702ae194b55b830f124c"
FRAME_RECT = (451, 1135, 899, 1589)
GLOW_RECT = (1, 1135, 449, 1589)
SOURCE_SATURATION = 0.05
SILVER_PALETTE = ("#c8c8c8", "#f9f9f9", "#737373")
# Uncommon through legendary, in the order used by the runtime UVs.
GEM_PALETTES = (
    ("#57e734", "#d8ffbd", "#237212"),
    ("#278df4", "#c4e8ff", "#124878"),
    ("#b44df2", "#e8c4ff", "#522270"),
    ("#ff891e", "#ffe2b3", "#763909"),
)


def runtime_housing(path, housing):
    """Keep the original housing and fill its neighbouring silver cell."""
    data = bytearray(path.read_bytes())
    width, height, levels = blp_bgra_levels(data)
    if (width, height) != (512, 128) or data[8] != 3 or len(levels) != 1:
        raise ValueError("Expected the existing single-level Raw3 jewelry atlas")
    offset = struct.unpack_from("<I", data, 20)[0]
    stride = 128 * 4
    for left, image in ((256, housing), (384, gemmed_housing(housing, SILVER_PALETTE))):
        pixels = image.tobytes("raw", "BGRA")
        for row in range(128):
            start = offset + (row * width + left) * 4
            data[start:start + stride] = pixels[row * stride:(row + 1) * stride]
    return bytes(data)


def contour_halo_alpha(housing):
    """Fade out from the outer metal edge, keeping the enclosed opening clear."""
    width, height = housing.size
    # This cutoff excludes the faint original glow and retains the metal tips.
    silhouette = housing.getchannel("A").point(lambda alpha: 255 if alpha >= 101 else 0)
    exterior = 128
    ImageDraw.floodfill(silhouette, (0, 0), exterior)
    outline = silhouette.load()
    spread = 8
    distances = {}
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            if outline[x, y] != 255 or exterior not in (
                outline[x - 1, y], outline[x + 1, y], outline[x, y - 1], outline[x, y + 1],
            ):
                continue
            for py in range(max(0, y - spread), min(height, y + spread + 1)):
                for px in range(max(0, x - spread), min(width, x + spread + 1)):
                    squared = (px - x) ** 2 + (py - y) ** 2
                    if squared < distances.get((px, py), spread ** 2):
                        distances[px, py] = squared

    alpha = Image.new("L", housing.size)
    pixels = alpha.load()
    for (x, y), squared in distances.items():
        distance = math.sqrt(squared)
        if outline[x, y] == exterior:
            fade = 1 - distance / spread
            # Taper against the crop boundary so the atlas has no hard edge.
            padding = min(x, y, width - 1 - x, height - 1 - y)
            coverage = fade * fade * (3 - 2 * fade) * min(1, padding / 2)
        else:
            # Tuck the inner falloff under the antialiased metal edge.
            coverage = max(0, 1 - distance / 2)
        pixels[x, y] = round(255 * 0.61 * coverage)
    return alpha


def gemmed_housing(housing, palette, clearance=None):
    """Bake a contour halo behind the grey metal and its gems above."""
    color, light, dark = palette
    halo_rgb = tuple(round(channel + (255 - channel) * 0.07) for channel in bytes.fromhex(color[1:]))
    halo = Image.new("RGBA", housing.size, halo_rgb)
    alpha = contour_halo_alpha(housing)
    if clearance is not None:
        from PIL import ImageChops

        alpha = ImageChops.multiply(alpha, clearance)
    halo.putalpha(alpha)
    frame = Image.alpha_composite(halo, housing)

    scale = 4
    gems = Image.new("RGBA", (128 * scale, 128 * scale))
    draw = ImageDraw.Draw(gems)
    for x, y, size in ((64, 17.5, 6.6), (21, 64, 3.55), (95, 34, 3.55), (95, 94, 3.55)):
        bezel = size + 1.1
        size += 0.35  # Show more color within the original bezel.
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


def attached_rarity_atlas(housing, path):
    """Use the shipped rail's coverage to clip the halo before compositing metal."""
    from PIL import ImageChops

    directory = ROOT / "media/tex/jewelry"
    # The three 400-pixel spans start after a one-pixel neighbour gutter.
    # Below the 152-pixel rail the action-bar background continues.
    rail = Image.new("L", (1200, 166), 255)
    for index, name in enumerate(("SocketRail.blp", "SocketRail_2.blp", "SocketRail_3.blp")):
        strip = image_from_bytes((directory / name).read_bytes()).getchannel("A")
        rail.paste(strip.crop((1, 0, 401, 152)), (400 * index, 0))

    clearance = Image.new("L", housing.size, 255)
    # At 36-unit buttons the housing uses 3 pixels per unit and the rail 4.
    scale = 4 / 3
    half = 64 * scale
    for center in range(264, 937, 168):
        coverage = rail.transform(
            housing.size, Image.Transform.AFFINE, (scale, 0, center - half, 0, scale, 80 - half),
            Image.Resampling.BILINEAR,
        )
        # Combine all five positions so reordering never exposes a halo over
        # a connector. Keep a smooth edge but fully clear the bevel itself.
        available = coverage.point(lambda alpha: max(0, 255 - 2 * alpha))
        clearance = ImageChops.darker(clearance, available)

    atlas = Image.new("RGBA", (512, 256))
    for index, palette in enumerate((SILVER_PALETTE, *GEM_PALETTES)):
        row, column = divmod(index, 4)
        atlas.paste(gemmed_housing(housing, palette, clearance), (column * 128, row * 128))
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
    parser.add_argument("--runtime", type=Path, help="Refresh the shared neutral and silver crops")
    parser.add_argument("--rarity", type=Path, help="Build the equipped gem and halo atlas")
    parser.add_argument("--attached", type=Path, help="Build the rarity atlas with the action-bar arch masked")
    options = parser.parse_args()
    if not (options.source or options.runtime or options.rarity or options.attached):
        parser.error("choose --source, --runtime, --rarity or --attached")
    if options.source:
        prepare(options.source, options.output)
    if options.runtime or options.rarity or options.attached:
        with Image.open(options.output) as retained:
            housing = retained.convert("RGBA")
        if housing.size != (128, 128):
            raise ValueError("Expected the retained 128-square Runecarver input")
        if options.runtime:
            options.runtime.write_bytes(runtime_housing(options.runtime, housing))
        if options.rarity:
            rarity_atlas(housing, options.rarity)
        if options.attached:
            attached_rarity_atlas(housing, options.attached)
