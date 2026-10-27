"""Prepare an original soft light mask without loading addon or game code."""

from pathlib import Path
import math

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "media/tex/tally/AffordableGlow.tga"
RAYS_OUTPUT = ROOT / "media/tex/tally/AffordableRays.tga"
SPARKLE_OUTPUT = ROOT / "media/tex/tally/AffordableSparkle.tga"
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
    rays = Image.new("RGBA", (128, 128), (255, 255, 255, 0))
    for y in range(128):
        vertical = (2 * y + 1) / 128 - 1
        for x in range(128):
            horizontal = (2 * x + 1) / 128 - 1
            radius = math.hypot(horizontal, vertical)
            angle = math.atan2(vertical, horizontal)
            ring = max(0, 1 - ((radius - 0.50) / 0.34) ** 2) ** 2
            beams = (0.10 + 0.60 * (0.5 + 0.5 * math.cos(3 * angle + 0.35)) ** 5
                     + 0.30 * (0.5 + 0.5 * math.cos(5 * angle - 0.70)) ** 7)
            head = 0.35 + 0.65 * (0.5 + 0.5 * math.cos(angle)) ** 2
            rays.putpixel((x, y), (255, 255, 255, round(255 * ring * beams * head)))
    rays.save(RAYS_OUTPUT, format="TGA", compression=None)
    sparkle = Image.new("RGBA", (32, 32), (255, 255, 255, 0))
    for y in range(32):
        vertical = abs((2 * y + 1) / 32 - 1)
        for x in range(32):
            horizontal = abs((2 * x + 1) / 32 - 1)
            center = max(0, 1 - math.hypot(horizontal, vertical) / 0.36) ** 2
            upright = math.exp(-(horizontal / 0.09) ** 2) * max(0, 1 - vertical / 0.9) ** 3
            across = math.exp(-(vertical / 0.09) ** 2) * max(0, 1 - horizontal / 0.9) ** 3
            alpha = 1 - (1 - center) * (1 - upright) * (1 - across)
            sparkle.putpixel((x, y), (255, 255, 255, round(255 * alpha)))
    sparkle.save(SPARKLE_OUTPUT, format="TGA", compression=None)


if __name__ == "__main__":
    prepare()
