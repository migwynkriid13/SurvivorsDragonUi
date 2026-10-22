#!/usr/bin/env python3
"""Compare fixed-pill artwork with the original three independently sampled crops.

Run by GitHub Actions only. This reads image data, never addon/game code.
"""

import math
from pathlib import Path
import struct
import tempfile

from prepare_timer_background import prepare


ART = Path(__file__).resolve().parents[1] / "media" / "tex" / "timer"


def load(name):
    data = (ART / name).read_bytes()
    width, height = struct.unpack_from("<HH", data, 12)
    assert data[1:3] == bytes((0, 2)) and data[16] == 32
    assert not data[17] & 16
    offset = 18 + data[0]
    rows = [
        [tuple(data[offset + (y * width + x) * 4 : offset + (y * width + x + 1) * 4])
         for x in range(width)]
        for y in range(height)
    ]
    return rows if data[17] & 32 else rows[::-1]


def sample(rows, x, y, crop_width):
    # Native cropped UV windows inset their clamp by half a texel. The original
    # center uses the full horizontal image, whose sampler clamps at its edge.
    x = min(crop_width - 0.5, max(0.5, x)) - 0.5
    y = min(17.5, max(0.5, y)) - 0.5
    x0, y0 = math.floor(x), math.floor(y)
    x1, y1 = min(len(rows[0]) - 1, x0 + 1), min(len(rows) - 1, y0 + 1)
    fx, fy = x - x0, y - y0
    return tuple(
        (rows[y0][x0][channel] * (1 - fx) + rows[y0][x1][channel] * fx) * (1 - fy)
        + (rows[y1][x0][channel] * (1 - fx) + rows[y1][x1][channel] * fx) * fy
        for channel in range(4)
    )


def main():
    left, center, right, fixed = (
        load(name) for name in (
            "BackgroundLeft.tga", "BackgroundCenter.tga",
            "BackgroundRight.tga", "BackgroundFixed.tga",
        )
    )
    assert len(fixed) == 32 and len(fixed[0]) == 512
    assert all(pixel == (0, 0, 0, 255) for row in center[:18] for pixel in row)
    # A removed per-quad clamp must meet the same constant texels on both sides.
    for y in range(18):
        assert left[y][28] == center[y][0] == right[y][0]
    with tempfile.TemporaryDirectory() as temporary:
        generated = Path(temporary) / "BackgroundFixed.tga"
        prepare(generated)
        assert generated.read_bytes() == (ART / "BackgroundFixed.tga").read_bytes()
    samples = 0
    # Dense fractional positions cover every cap texel and both former joins.
    # The center's complete horizontal extent is constant, as asserted above.
    xs = set(i / 16 for i in range(0, 31 * 16 + 1))
    xs.update(253 + i / 16 for i in range(0, 31 * 16 + 1))
    xs.update((64.25, 128.5, 200.75))
    for x in sorted(xs):
        for yi in range(18 * 8 + 1):
            y = yi / 8
            if x < 29:
                original = sample(left, x, y, 29)
            elif x < 255:
                original = sample(center, (x - 29) * 64 / 226, y, 64)
            else:
                original = sample(right, x - 255, y, 29)
            combined = sample(fixed, x, y, 284)
            assert all(abs(a - b) < 1e-8 for a, b in zip(original, combined)), (x, y)
            samples += 1
    print(f"Fixed timer background matches original crop sampling at {samples:,} positions.")


if __name__ == "__main__":
    main()
