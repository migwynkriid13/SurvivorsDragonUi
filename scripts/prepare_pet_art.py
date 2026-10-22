"""Convert pet-frame pieces without changing their pixels.

Requires Pillow; reads artwork only and never loads addon or game code.
"""

import argparse
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def prepare(sources, output):
    output.mkdir(parents=True, exist_ok=True)
    for name in ("Background", "Border"):
        data = (sources / (name + ".blp")).read_bytes()
        # The BLP2 pieces use uncompressed BGRA (encoding 3).
        width, height = struct.unpack_from("<II", data, 12)
        offset = struct.unpack_from("<I", data, 20)[0]
        image = Image.frombytes(
            "RGBA", (width, height), data[offset : offset + width * height * 4], "raw", "BGRA"
        )
        image.save(output / (name + ".tga"), compression=None)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "media/tex/pets")
    options = parser.parse_args()
    prepare(options.sources, options.output)
