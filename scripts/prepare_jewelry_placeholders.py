"""Draw original gray empty-slot silhouettes without loading addon code.

The three small circular icons are generated geometry, not character-screen
artwork. Pillow writes uncompressed RGBA TGA files for the legacy texture API.
An optional PNG contact sheet is artwork only, not a game or addon preview.
"""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SIZE = 64
SCALE = 4
GRAY = (115, 118, 121, 255)
LIGHT = (143, 146, 149, 255)
DARK = (65, 68, 71, 255)


def box(values):
    return tuple(round(value * SCALE) for value in values)


def polygon(draw, points, fill):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill)


def background():
    image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE))
    pixels = image.load()
    for y in range(SIZE * SCALE):
        for x in range(SIZE * SCALE):
            px, py = (x + 0.5) / SCALE - 32, (y + 0.5) / SCALE - 32
            radius = math.hypot(px, py)
            if radius <= 31.5:
                shade = round(29 + 9 * (1 - radius / 31.5) - 3 * py / 32)
                pixels[x, y] = (shade, shade + 2, shade + 4, 248)
    return image


def necklace(draw):
    chain = []
    for step in range(65):
        t = step / 64
        # A plain chain dips toward the pendant without tiny unreadable links.
        x = 17 + 30 * t
        y = 14 + 22 * math.sin(math.pi * t)
        chain.append((round(x * SCALE), round(y * SCALE)))
    draw.line(chain, fill=GRAY, width=3 * SCALE, joint="curve")
    draw.ellipse(box((28.5, 34, 35.5, 41)), outline=LIGHT, width=2 * SCALE)
    polygon(draw, [(32, 39), (40, 46), (32, 55), (24, 46)], GRAY)
    polygon(draw, [(32, 41), (37, 46), (32, 51)], LIGHT)
    polygon(draw, [(26, 46), (32, 53), (32, 46)], DARK)


def ring(draw):
    draw.ellipse(box((17, 26, 47, 53)), fill=GRAY)
    draw.ellipse(box((23, 31, 41, 47)), fill=(30, 32, 34, 255))
    draw.arc(box((18.5, 27.5, 45.5, 51.5)), 30, 160, fill=LIGHT, width=2 * SCALE)
    polygon(draw, [(23, 22), (28, 14), (36, 14), (41, 22), (32, 31)], GRAY)
    polygon(draw, [(26, 21), (29, 16), (35, 16), (38, 21), (32, 28)], LIGHT)
    polygon(draw, [(26, 21), (38, 21), (32, 28)], DARK)


def trinket(draw):
    draw.ellipse(box((27, 10, 37, 22)), outline=GRAY, width=3 * SCALE)
    draw.rounded_rectangle(box((29, 19, 35, 28)), radius=2 * SCALE, fill=GRAY)
    draw.ellipse(box((17, 25, 47, 55)), fill=GRAY)
    draw.arc(box((19, 27, 45, 53)), 190, 340, fill=LIGHT, width=2 * SCALE)
    polygon(draw, [(32, 31), (40, 40), (32, 49), (24, 40)], DARK)
    polygon(draw, [(32, 35), (36, 40), (32, 45), (28, 40)], LIGHT)


def prepare(output, preview):
    output.mkdir(parents=True, exist_ok=True)
    images = []
    for name, paint in (("Neck", necklace), ("Ring", ring), ("Trinket", trinket)):
        image = background()
        paint(ImageDraw.Draw(image))
        image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
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
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/jewelry")
    parser.add_argument("--preview", type=Path)
    options = parser.parse_args()
    prepare(options.output, options.preview)
