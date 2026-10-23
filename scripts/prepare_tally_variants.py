"""Prepare tally edge corrections and detached surrounds; never load addon code.

Requires Pillow and the five pinned originals in third_party/tally-sources.json.
Existing attached artwork and core/tally.lua supply the unchanged style choices.
Outputs are staged for review rather than overwriting the installed addon.
"""

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
SCALE = 2
WIDTH = 600
CANVAS = (1024, 128)


def grade(image, saturation, brightness):
    alpha = image.getchannel("A")
    image = ImageEnhance.Color(image).enhance(saturation)
    image = ImageEnhance.Brightness(image).enhance(brightness)
    image.putalpha(alpha)
    return image


def paste(canvas, image, x, y, width, height):
    image = image.resize((round(width * SCALE), round(height * SCALE)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(image, (round(x * SCALE), round(y * SCALE)))


def slice_three(canvas, image, height, cap):
    width, source_height = image.size
    end = min(66, cap * height / source_height)
    paste(canvas, image.crop((0, 0, cap, source_height)), 0, 0, end, height)
    paste(canvas, image.crop((cap, 0, width - cap, source_height)), end, 0, 300 - 2 * end, height)
    paste(canvas, image.crop((width - cap, 0, width, source_height)), 300 - end, 0, end, height)


def fill_inside(frame, body, height, project_top=False):
    mask = Image.new("L", CANVAS)
    draw = ImageDraw.Draw(mask)
    alpha = frame.getchannel("A")
    for x in range(WIDTH):
        rows = [y for y in range(round(height * SCALE)) if alpha.getpixel((x, y)) >= 96]
        if rows:
            draw.line((x, 0 if project_top else rows[0], x, rows[-1]), fill=255)
    result = Image.new("RGBA", CANVAS)
    tile = body.resize((round(body.width * height / body.height * SCALE), round(height * SCALE)),
                       Image.Resampling.LANCZOS)
    band = Image.new("RGBA", (WIDTH, tile.height))
    for x in range(0, WIDTH, tile.width):
        band.alpha_composite(tile, (x, 0))
    result.alpha_composite(band)
    result.putalpha(ImageChops.multiply(result.getchannel("A"), mask))
    result.alpha_composite(frame)
    return result


def plain_reliquary(source, body):
    frame = Image.new("RGBA", CANVAS)
    for crop, x, y, width, height in (
        ((58, 60, 106, 106), 0, 0, 31, 36),
        ((406, 60, 454, 106), 269, 0, 31, 36),
        ((106, 88, 400, 106), 29, 23, 242, 14),
    ):
        paste(frame, grade(source.crop(crop), .4, 1.2), x, y, width, height)
    return fill_inside(frame, body, 36, project_top=True)


def repair_attached(sources):
    knotted = Image.new("RGBA", CANVAS)
    slice_three(knotted, grade(sources["knotted"].crop((3, 22, 253, 51)), .25, 1.25), 37, 30)
    cornice = Image.new("RGBA", CANVAS)
    source = grade(sources["cornice"].crop((345, 24, 679, 63)), .45, 1.4)
    shoulder = [(0, 10), (3, 9), (8, 8), (13, 6), (17, 3), (20, 0)]
    top = shoulder + [(source.width - 1 - x, y) for x, y in reversed(shoulder)]
    mask = Image.new("L", source.size)
    ImageDraw.Draw(mask).polygon(top + [(source.width - 1, source.height - 1), (0, source.height - 1)], fill=255)
    source.putalpha(ImageChops.multiply(source.getchannel("A"), mask))
    paste(cornice, source, 0, 0, 300, 40)
    return {"gothic07": knotted, "gothic10": cornice}


def number(value):
    return str(int(value)) if value == int(value) else str(value)


def prepare(originals, output):
    output.mkdir(parents=True, exist_ok=True)
    sources = {}
    records = json.loads((ROOT / "third_party/tally-sources.json").read_text())
    for key, record in records.items():
        path = originals / record["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
            raise ValueError("Original artwork differs from the pinned source: " + str(path))
        sources[key] = Image.open(path).convert("RGBA")
    body = grade(sources["body"].crop((0, 32, 64, 44)), .2, .62)
    repaired = repair_attached(sources)
    registry = (ROOT / "core/tally.lua").read_text()
    recipe = []

    def variant(match):
        block = match.group(0)
        identifier = re.search(r'^        id = "([^"]+)",', block, re.M).group(1)
        texture = re.search(r'^        texture = "([^"]+)",', block, re.M).group(1)
        center_y = float(re.search(r'^        contentY = ([\d.]+),', block, re.M).group(1))
        image = repaired.get(identifier)
        if image is None:
            image = Image.open(ROOT / "media/tex/tally" / texture).convert("RGBA")
        else:
            image.save(output / texture, compression=None)
        if identifier == "gothic04":
            frame = Image.new("RGBA", CANVAS)
            slice_three(frame, grade(sources["iron"].crop((0, 0, 256, 32)), .38, 1.25), 40, 27)
            detached = fill_inside(frame, body, 40)
            extent, center = 40, 20
        else:
            frame = plain_reliquary(sources["reliquary"], body) if identifier == "gothic13" else image
            start = round(center_y * SCALE)
            upper = frame.crop((0, start, WIDTH, frame.getbbox()[3])).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            lower = image.crop((0, start, WIDTH, image.getbbox()[3]))
            detached = Image.new("RGBA", CANVAS)
            detached.alpha_composite(upper)
            detached.alpha_composite(lower, (0, upper.height))
            extent, center = (upper.height + lower.height) / SCALE, upper.height / SCALE
        name = identifier + "_detached.tga"
        detached.save(output / name, compression=None)
        entry = ("        detached = {\n"
                 '            texture = "' + name + '",\n'
                 "            extent = " + number(extent) + ",\n"
                 "            contentY = " + number(center) + ",\n"
                 "        },\n")
        recipe.append({"id": identifier, "texture": name, "extent": extent, "contentY": center})
        return re.sub(r'^        detached = \{\n.*?^        \},\n', entry, block, flags=re.M | re.S)

    registry = re.sub(r'^    \{\n.*?^    \},\n', variant, registry, flags=re.M | re.S)
    (output / "tally.lua").write_text(registry)
    (output / "recipe.json").write_text(json.dumps(recipe, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--originals", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "dist/tally-prepared")
    arguments = parser.parse_args()
    prepare(arguments.originals, arguments.output)
