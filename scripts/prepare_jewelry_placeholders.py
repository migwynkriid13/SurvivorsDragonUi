"""Prepare the selected WoW empty-slot artwork without executing addon code.

Original source PNGs and their immutable pin are recorded in
third_party/Jewelry-ARTWORK.md. This prepares TGA inputs; afterwards run
prepare_client_textures.py to produce the existing runtime BLP filenames.
"""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
SIZE = 64
SCALE = 4
SOURCE_INTERIOR = (4, 4, 60, 60)
SOURCES = (
    ("Neck", "UI-PaperDoll-Slot-Neck.PNG", 50),
    ("Ring", "UI-PaperDoll-Slot-Finger.PNG", 54),
    ("Trinket", "UI-PaperDoll-Slot-Trinket.PNG", 40),
)


def background():
    image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE))
    pixels = image.load()
    for y in range(SIZE * SCALE):
        for x in range(SIZE * SCALE):
            px, py = (x + 0.5) / SCALE - 32, (y + 0.5) / SCALE - 32
            radius = math.hypot(px, py)
            if radius <= 31.5:
                shade = round(18 + 5 * (1 - radius / 31.5) - 2 * py / 32)
                pixels[x, y] = (shade, shade + 1, shade + 2, 255)
    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def placeholder(source, art_size):
    with Image.open(source) as original:
        artwork = original.convert("RGBA").crop(SOURCE_INTERIOR)
    artwork = ImageEnhance.Brightness(artwork).enhance(1.55)
    artwork = artwork.resize((art_size, art_size), Image.Resampling.LANCZOS)
    image = background()
    alpha = image.getchannel("A")
    offset = (SIZE - art_size) // 2
    bounds = (offset, offset, offset + art_size, offset + art_size)
    # Fill more of the opening with the painted ring and necklace, while the
    # trinket grows only slightly. Keep the full source interior and its ratio.
    # Lift only the source's dark ground into the same charcoal recess, so
    # the original square backdrop does not leave another visible frame.
    image.paste(ImageChops.lighter(image.crop(bounds), artwork), (offset, offset))
    image.putalpha(alpha)
    return image


def prepare(sources, output, preview):
    output.mkdir(parents=True, exist_ok=True)
    images = []
    for name, filename, art_size in SOURCES:
        image = placeholder(sources / filename, art_size)
        image.save(output / f"Empty{name}.tga", compression=None)
        images.append(image)
    if preview:
        preview.parent.mkdir(parents=True, exist_ok=True)
        sheet = Image.new("RGBA", (SIZE * 3 + 32, SIZE + 16), (18, 19, 21, 255))
        for index, image in enumerate(images):
            sheet.alpha_composite(image, (8 + index * (SIZE + 8), 8))
        sheet.resize((sheet.width * 3, sheet.height * 3), Image.Resampling.NEAREST).save(preview)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, default=ROOT / "third_party/sources/jewelry")
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry")
    parser.add_argument("--preview", type=Path)
    options = parser.parse_args()
    prepare(options.sources, options.output, options.preview)
