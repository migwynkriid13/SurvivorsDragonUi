"""Prepare the selected affix icon atlas as image data, without running Lua."""

import hashlib
import json

from PIL import Image, ImageChops

from prepare_client_textures import save_image
from preview_affix_designs import COMMIT, DESIGNS, ROOT, SOURCES, round_mask


def main():
    title, _, *names = DESIGNS[3]
    atlas = Image.new("RGBA", (256, 64))
    records = []
    for index, name in enumerate(names):
        source = SOURCES / (name + ".PNG")
        original = Image.open(source).convert("RGBA")
        crop = (4, 4, original.width - 4, original.height - 4)
        icon = original.crop(crop).resize((64, 64), Image.Resampling.LANCZOS)
        icon.putalpha(ImageChops.multiply(icon.getchannel("A"), round_mask(64)))
        atlas.alpha_composite(icon, (index * 64, 0))
        records.append({"source": source.relative_to(ROOT).as_posix(),
                        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                        "crop": list(crop), "destination": [index * 64, 0, (index + 1) * 64, 64]})
    destination = ROOT / "media/tex/timer/Affixes.blp"
    save_image(atlas, destination)
    record = {"proposal": 4, "title": title, "source_commit": COMMIT,
              "destination": destination.relative_to(ROOT).as_posix(),
              "canvas": list(atlas.size), "sources": records,
              "ring": {"source": "media/tex/jewelry/Frame.blp", "crop": [664, 56, 736, 128],
                       "vertex_color": [237 / 255, 35 / 255, 38 / 255, 1]},
              "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}
    (ROOT / "third_party/affix-selected-art.json").write_text(json.dumps(record, indent=2) + "\n")
    print("Prepared selected #04 affix atlas; the ring remains the existing neutral jewelry artwork.")


if __name__ == "__main__":
    main()
