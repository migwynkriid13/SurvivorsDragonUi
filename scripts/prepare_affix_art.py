"""Prepare the selected affix icon atlas as image data, without running Lua."""

import hashlib
import json

from PIL import Image

from prepare_client_textures import save_image
from preview_affix_designs import COMMIT, DESIGNS, ROOT, SOURCES


def main():
    title, _, *names = DESIGNS[3]
    atlas = Image.new("RGBA", (256, 64))
    records = []
    for index, name in enumerate(names):
        source = SOURCES / (name + ".PNG")
        original = Image.open(source).convert("RGBA")
        crop = (4, 4, original.width - 4, original.height - 4)
        icon = original.crop(crop).resize((64, 64), Image.Resampling.LANCZOS)
        atlas.alpha_composite(icon, (index * 64, 0))
        records.append({"source": source.relative_to(ROOT).as_posix(),
                        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                        "crop": list(crop), "destination": [index * 64, 0, (index + 1) * 64, 64]})
    destination = ROOT / "media/tex/timer/Affixes.blp"
    save_image(atlas, destination)
    record = {"proposal": 4, "title": title, "source_commit": COMMIT,
              "destination": destination.relative_to(ROOT).as_posix(),
              "canvas": list(atlas.size), "sources": records,
              "frame": {"proposal": 2, "title": "Minimap bevel",
                        "source": "media/tex/minimap/LauncherBackground.blp", "canvas": [32, 32],
                        "crop": [0, 3, 29, 29], "display_size": [25, 23], "icon_size": [16, 16],
                        "gold_bounds": [4, 5, 27, 27], "icon_center_offset": [25 / 29, 0],
                        "gap": 5, "layer": "BACKGROUND",
                        "source_commit": "e80e3278cc833c89e1f3fc79557b68315d750935",
                        "source_path": "BUTTONS/UI-SquareButton-Up.PNG"},
              "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()}
    (ROOT / "third_party/affix-selected-art.json").write_text(json.dumps(record, indent=2) + "\n")
    print("Prepared selected #04 square affix pictures with the existing #02 minimap bevel background.")


if __name__ == "__main__":
    main()
