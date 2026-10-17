"""Prepare the selected five-slot jewelry texture without loading addon code.

Requires Pillow and a scratch source directory containing the three pinned
upstream images listed in third_party/Jewelry-ARTWORK.md. No fonts or item
icons are baked into the shipped artwork.
"""

import argparse
import struct
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SCALE = 4
GOLD = (191, 158, 91)


def rgba(path):
    data = path.read_bytes()
    # Pillow does not decode this uncompressed BLP2 variant itself.
    if len(data) >= 148 and data[:4] == b"BLP2" and data[8] == 3:
        width, height = struct.unpack_from("<II", data, 12)
        offset = struct.unpack_from("<I", data, 20)[0]
        return Image.frombytes(
            "RGBA", (width, height), data[offset : offset + width * height * 4], "raw", "BGRA"
        )
    return Image.open(path).convert("RGBA")


def prepare(sources, output):
    stone = rgba(sources / "CastingBarBackground.blp")
    ring = rgba(sources / "bagborder2.blp")
    filigree = rgba(sources / "IconFrameGold.tga").crop((0, 90, 114, 123)).rotate(90, expand=True)
    trim = rgba(ROOT / "media/tex/timer/BorderCenter.tga").crop((21, 0, 42, 7))
    core, width, height, scale = 253, 317, 88, SCALE
    image = Image.new("RGBA", (width * scale, height * scale))

    def paste(source, x, y, w, h):
        piece = source.resize((round(w * scale), round(h * scale)), Image.Resampling.LANCZOS)
        image.alpha_composite(piece, (round(x * scale), round(y * scale)))

    bounds = (32 * scale, 18 * scale, (32 + core) * scale, 75 * scale)
    shadow = Image.new("RGBA", image.size)
    ImageDraw.Draw(shadow).rounded_rectangle(
        (bounds[0], bounds[1] + 3 * scale, bounds[2], bounds[3] + 3 * scale),
        radius=28.5 * scale,
        fill=(0, 0, 0, 180),
    )
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(3 * scale)))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        bounds, radius=28.5 * scale, fill=(11, 16, 17, 255), outline=(*GOLD, 255), width=round(1.3 * scale)
    )
    texture = stone.resize((core * scale, 57 * scale), Image.Resampling.LANCZOS)
    mask = Image.new("L", texture.size)
    ImageDraw.Draw(mask).rounded_rectangle(
        (3 * scale, 3 * scale, (core - 3) * scale, 54 * scale), radius=25.5 * scale, fill=76
    )
    texture.putalpha(ImageChops.multiply(texture.getchannel("A"), mask))
    image.alpha_composite(texture, (32 * scale, 18 * scale))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (34 * scale, 20 * scale, (30 + core) * scale, 73 * scale),
        radius=26.5 * scale,
        outline=(*GOLD, 60),
        width=round(0.6 * scale),
    )
    paste(trim, 60.5, 18.4, core - 57, 5)
    paste(ImageOps.flip(trim), 60.5, 69.6, core - 57, 5)
    for center in (41, core + 23):
        draw.ellipse(
            ((center - 2) * scale, 44.5 * scale, (center + 2) * scale, 48.5 * scale), fill=(*GOLD, 255)
        )
    paste(filigree, 14, 18, 24, 58)
    paste(ImageOps.mirror(filigree), core + 26, 18, 24, 58)
    apertures = Image.new("L", image.size)
    aperture_draw = ImageDraw.Draw(apertures)
    for index in range(5):
        x, y = 54.5 + index * 44, 30.5
        aperture_draw.ellipse((x * scale, y * scale, (x + 32) * scale, (y + 32) * scale), fill=255)
    image.putalpha(ImageChops.subtract(image.getchannel("A"), apertures))
    for index in range(5):
        paste(ring, 49 + index * 44, 25, 43, 43)
    canvas = Image.new("RGBA", (1024, 256))
    canvas.alpha_composite(image.resize((width * 2, height * 2), Image.Resampling.LANCZOS))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry/Frame.tga")
    options = parser.parse_args()
    prepare(options.sources, options.output)
