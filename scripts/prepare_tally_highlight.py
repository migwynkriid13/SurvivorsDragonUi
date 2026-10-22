"""Prepare an original soft light mask without loading addon or game code."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "media/tex/tally/AffordableGlow.tga"
SIZE = (64, 32)


def prepare():
    image = Image.new("RGBA", SIZE, (255, 255, 255, 0))
    for y in range(SIZE[1]):
        vertical = (2 * y + 1) / SIZE[1] - 1
        for x in range(SIZE[0]):
            horizontal = (2 * x + 1) / SIZE[0] - 1
            falloff = max(0, 1 - horizontal * horizontal - vertical * vertical)
            image.putpixel((x, y), (255, 255, 255, round(255 * falloff ** 3)))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT, format="TGA", compression=None)


if __name__ == "__main__":
    prepare()
