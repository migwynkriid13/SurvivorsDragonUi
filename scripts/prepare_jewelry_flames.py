"""Prepare a moving housing-edge shimmer; no addon code is loaded."""

import math
from pathlib import Path

from PIL import Image, ImageFilter

from prepare_client_textures import blp_from_bgra


ROOT = Path(__file__).resolve().parents[1]


def prepare():
    # Match the existing housing canvas. Its alpha shapes a soft edge shimmer,
    # with less than one local unit of lift instead of separate flame plumes.
    atlas = Image.new("RGBA", (256, 256), (255, 255, 255, 0))
    size = 43 * 128 / 108
    housing = Image.open(ROOT / "media/tex/jewelry/Runecarver.tga").convert("RGBA")
    edge = housing.getchannel("A").resize((64, 64), Image.Resampling.LANCZOS)
    edge = edge.filter(ImageFilter.GaussianBlur(0.65))
    for frame in range(16):
        phase = frame / 16 * math.tau
        cell = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
        pixels = cell.load()
        for py in range(1, 63):
            y = size / 2 - (py + 0.5) * size / 64
            for px in range(1, 63):
                x = (px + 0.5) * size / 64 - size / 2
                radius = math.hypot(x, y)
                if radius < 17.5 or radius > 24.8:
                    continue
                angle = math.atan2(y, x)
                lift = 0.35 * (1 + math.sin(angle * 5 - phase))
                source_y = min(63, py + round(lift * 64 / size))
                shape = edge.getpixel((px, source_y)) / 255
                band = math.exp(-((radius - 20) / 2.25) ** 2)
                # Distinct bright patches travel upward through dark gaps.
                # Contrast changes within the same tightly bounded artwork.
                drift = (0.5 + 0.5 * math.sin(y * 0.6 - phase + 0.45 * math.sin(angle * 3))) ** 3
                alpha = shape * band * (0.06 + 0.78 * drift)
                pixels[px, py] = (255, 255, 255, round(alpha * 255))
        atlas.paste(cell, ((frame % 4) * 64, (frame // 4) * 64))
    target = ROOT / "media/tex/jewelry/RarityFlames.tga"
    atlas.save(target, compression=None)
    target.with_suffix(".blp").write_bytes(blp_from_bgra(256, 256, atlas.tobytes("raw", "BGRA")))


if __name__ == "__main__":
    prepare()
