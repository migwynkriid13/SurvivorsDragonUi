"""Repair the pinned meter background's lower rail without changing its canvas or alpha."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image

from prepare_client_textures import blp_from_bgra, lossless_palette

ROOT = Path(__file__).resolve().parents[1]
SOURCE_RGBA_SHA256 = "b2a94f8fde2559cb2ede6c17d08b31b35dc671bf9712c8c7b7f08149d5dc87eb"


def prepare(source, destination):
    image = Image.open(source).convert("RGBA")
    if image.size != (256, 32) or hashlib.sha256(image.tobytes()).hexdigest() != SOURCE_RGBA_SHA256:
        raise ValueError("Use the original pinned Details TWW background, decoded to RGBA/TGA")
    # The source's four bottom rows contain dark compression blocks near 44%.
    # Interpolate only this small straight-rail span between intact neighbours;
    # retain the original alpha, corners, upper rail and all body/fill pixels.
    pixels = image.load()
    for y in range(28, 32):
        left, right = pixels[99, y], pixels[156, y]
        for x in range(100, 156):
            original = pixels[x, y]
            rgb = tuple((left[c] * (156 - x) + right[c] * (x - 99) + 28) // 57 for c in range(3))
            pixels[x, y] = rgb + (original[3],)
    destination.mkdir(parents=True, exist_ok=True)
    image.save(destination / "Background.tga")
    packed = lossless_palette(blp_from_bgra(256, 32, image.tobytes("raw", "BGRA")))
    (destination / "Background.blp").write_bytes(packed)
    return {"source_rgba_sha256": SOURCE_RGBA_SHA256,
            "derived_rgba_sha256": hashlib.sha256(image.tobytes()).hexdigest(),
            "runtime_sha256": hashlib.sha256(packed).hexdigest(),
            "pixel_span": {"x": [100, 155], "y": [28, 31]},
            "unaffected_top_bgra_sha256": hashlib.sha256(image.tobytes("raw", "BGRA")[:28 * 256 * 4]).hexdigest()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output-directory", type=Path, default=ROOT / "media/tex/meter")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    result = prepare(args.source, args.output_directory)
    if args.receipt:
        args.receipt.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
