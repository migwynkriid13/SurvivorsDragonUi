"""Rasterize Bildad's I/V/X glyphs as a static, personal-use timer atlas.

No font is installed or retained. The public source archive stays in memory;
--font can supply the same pinned TTF from a separately licensed local copy.
"""

import argparse
import hashlib
import html
import io
import json
from pathlib import Path
import re
import time
import urllib.request
import zipfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from prepare_client_textures import save_image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = "https://www.fontget.com/font/bildad/"
FONT_SHA256 = "a35066a71965582df52571d5cd679cdcf416179c15f6dbfe83f7c76abc905929"
NUMERALS = ("I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X")
CELL = (128, 64)
CANVAS = (512, 256)
FONT_SIZE = 66
OUTLINE = 3


def read_public_font():
    headers = {"User-Agent": "SurvivorsDragonUi artwork preparation"}
    request = urllib.request.Request(SOURCE + "?sdui=" + str(time.time_ns()), headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        page = response.read().decode("utf-8")
    match = re.search(r'https://dl\.fontget\.com/b/i/bildad/bildad\.zip\?[^"<>]+', page)
    if not match:
        raise RuntimeError("FontGet did not publish the expected Bildad download")
    request = urllib.request.Request(html.unescape(match.group()), headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = response.read()
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        font = archive.read("bildad/Bildad.ttf")
        notice = archive.read("bildad/LICENSE.md").decode("utf-8").strip()
    return font, notice


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--font", type=Path, help="The pinned Bildad.ttf; never copied into the addon")
    args = parser.parse_args()
    if args.font:
        font_bytes = args.font.read_bytes()
        notice = (ROOT / "media/tex/timer/LICENSE.txt").read_text(encoding="utf-8")
        notice = notice.split("Downloaded archive license (verbatim):\n", 1)[1].strip()
    else:
        font_bytes, notice = read_public_font()
    if hashlib.sha256(font_bytes).hexdigest() != FONT_SHA256:
        raise RuntimeError("Bildad source changed; review its glyphs and license before replacing the pin")

    font = ImageFont.truetype(io.BytesIO(font_bytes), FONT_SIZE)
    bounds = [font.getbbox(text) for text in NUMERALS]
    top = min(box[1] for box in bounds)
    bottom = max(box[3] for box in bounds)
    y = (CELL[1] - (bottom - top)) // 2 - top
    atlas = Image.new("RGBA", CANVAS)
    entries = []
    for index, (text, box) in enumerate(zip(NUMERALS, bounds)):
        x = (CELL[0] - (box[2] - box[0])) // 2 - box[0]
        mask = Image.new("L", CELL)
        ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
        outline = mask.filter(ImageFilter.MaxFilter(OUTLINE * 2 + 1))
        tile = Image.new("RGBA", CELL, (0, 0, 0, 0))
        tile.putalpha(outline)
        ink = Image.new("RGBA", CELL, "white")
        ink.putalpha(mask)
        tile.alpha_composite(ink)
        column, row = index % 4, index // 4
        atlas.alpha_composite(tile, (column * CELL[0], row * CELL[1]))
        entries.append({"level": index + 1, "numeral": text, "cell": [column, row]})

    stem = ROOT / "media/tex/timer/HeroicNumerals"
    outputs = []
    for suffix in (".tga", ".blp"):
        destination = stem.with_suffix(suffix)
        save_image(atlas, destination)
        outputs.append({"path": destination.relative_to(ROOT).as_posix(),
                        "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
    credit = (
        "Bildad numeral artwork - personal use\n"
        "Source: " + SOURCE + "\n"
        "Credit: FontGet.com\n"
        "Font copyright: Bildad © (FontGet). 2023. All Rights Reserved\n\n"
        "Only rasterized I/V/X combinations are included. No font file is shipped.\n"
        "Commercial use requires an appropriate license from the rights holder.\n\n"
        "Downloaded archive license (verbatim):\n" + notice + "\n"
    )
    (ROOT / "media/tex/timer/LICENSE.txt").write_text(credit, encoding="utf-8")
    record = {"source": SOURCE, "font": "Bildad Regular", "font_sha256": FONT_SHA256,
              "license": "Free for personal use; credit FontGet.com",
              "glyphs": ["I", "V", "X"], "font_size": FONT_SIZE,
              "outline_pixels": OUTLINE, "canvas": list(CANVAS), "cell": list(CELL),
              "runtime_size": [32, 16], "entries": entries, "outputs": outputs}
    (ROOT / "third_party/heroic-numerals-art.json").write_text(json.dumps(record, indent=2) + "\n")
    print("Prepared Bildad I–X in HeroicNumerals.blp and its TGA authoring source; no font retained.")


if __name__ == "__main__":
    main()
