"""Prepare tally edge corrections and detached surrounds; never load addon code.

Requires Pillow and the pinned originals in third_party/tally-sources.json.
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


def mirror_sides(image):
    result = image.copy()
    result.paste(image.crop((0, 0, WIDTH // 2, image.height)).transpose(Image.Transpose.FLIP_LEFT_RIGHT),
                 (WIDTH // 2, 0))
    return result


def reliquary(sources, body, detached):
    # Restore the complete native wings above the attached crop instead of
    # reflecting through their middle. Only the lower rail becomes a top rail.
    rise = 16 if detached else 0
    source = sources["reliquary"]
    frame = Image.new("RGBA", CANVAS)
    cap = grade(source.crop((58, 40 if detached else 60, 106, 106)), .4, 1.2)
    paste(frame, cap, 0, 0, 31, 36 + rise)
    rail = grade(source.crop((106, 88, 400, 106)), .4, 1.2)
    paste(frame, rail, 29, 23 + rise, 242, 14)
    if detached:
        paste(frame, rail.transpose(Image.Transpose.FLIP_TOP_BOTTOM), 29, 0, 242, 14)
    frame = mirror_sides(frame)
    result = mirror_sides(fill_inside(frame, body, 36 + rise, project_top=not detached))
    footer = grade(sources["pendant"].crop((208, 100, 304, 128)), .42, 1.25)
    width = 62 * 14 / 18
    paste(result, footer, 150 - width / 2, 26 + rise, width, 14)
    return result


def close_iron(image):
    # The attached side walls and lower cornerwork stay at their original size.
    # Inset the reflected bevel to meet those walls, rather than the lower flare.
    upper = image.crop((7, 60, WIDTH - 7, 72)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    upper = upper.resize((WIDTH, 12), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", CANVAS)
    result.alpha_composite(upper)
    result.alpha_composite(image.crop((0, 0, WIDTH, 72)), (0, 12))
    return result


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
        if identifier == "gothic13":
            image = reliquary(sources, body, False)
            image.save(output / texture, compression=None)
            detached = reliquary(sources, body, True)
            extent, center = detached.getbbox()[3] / SCALE, center_y + 16
        elif identifier == "gothic04":
            detached = close_iron(image)
            extent, center = detached.getbbox()[3] / SCALE, center_y + 6
        else:
            start = round(center_y * SCALE)
            upper = image.crop((0, start, WIDTH, image.getbbox()[3])).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
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
