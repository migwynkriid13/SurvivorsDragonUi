#!/usr/bin/env python3
"""Assemble the fixed-width pill background from the shipped Blizzard crops."""

import argparse
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "media" / "tex" / "timer"
CONTENT_WIDTH, CONTENT_HEIGHT = 284, 18
CANVAS_WIDTH, CANVAS_HEIGHT = 512, 32


def read_rows(path):
    """Read the existing uncompressed, 32-bit BGRA crops in top-first order."""
    data = path.read_bytes()
    width, height = struct.unpack_from("<HH", data, 12)
    if data[1] != 0 or data[2] != 2 or data[16] != 32 or data[17] & 16:
        raise ValueError(f"Unsupported source TGA: {path}")
    start = 18 + data[0]
    rows = [data[start + y * width * 4 : start + (y + 1) * width * 4] for y in range(height)]
    return rows if data[17] & 32 else rows[::-1]


def prepare(output):
    left = read_rows(ART / "BackgroundLeft.tga")
    center = read_rows(ART / "BackgroundCenter.tga")
    right = read_rows(ART / "BackgroundRight.tga")
    # The original 64-wide center is horizontally uniform opaque black. Its
    # 226-unit stretch and both cap joins therefore retain identical samples.
    rows = [
        left[y][: 29 * 4] + center[y][:4] * 226 + right[y][: 29 * 4]
        + bytes((CANVAS_WIDTH - CONTENT_WIDTH) * 4)
        for y in range(CONTENT_HEIGHT)
    ]
    rows.extend([bytes(CANVAS_WIDTH * 4)] * (CANVAS_HEIGHT - CONTENT_HEIGHT))
    header = struct.pack(
        "<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0,
        CANVAS_WIDTH, CANVAS_HEIGHT, 32, 8,
    )
    output.write_bytes(header + b"".join(reversed(rows)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ART / "BackgroundFixed.tga")
    prepare(parser.parse_args().output)
