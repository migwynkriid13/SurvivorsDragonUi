"""Prepare lossless BLP artwork for native and browser Wenilla clients.

The runtime manifest names the final files. Existing artwork generators may
produce TGA inputs; run this step afterwards. No addon or game code is executed.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
TARGET_HEALTH = "media/tex/unitframes/UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health"
# The original pet BLP and retained compact-fill TGA have distinct pixels.
TGA_SOURCES = {
    TARGET_HEALTH + ".blp": None,
}


def blp_bgra_levels(data):
    """Read Raw1/Raw3 pixels using the native decoder's palette/alpha layout."""
    if len(data) < 1172 or data[:4] != b"BLP2" or data[8] not in (1, 3):
        raise ValueError("Expected Raw1 or Raw3 BLP2")
    width, height = struct.unpack_from("<II", data, 12)
    if width <= 0 or height <= 0 or data[9] not in (0, 1, 4, 8):
        raise ValueError("Invalid BLP dimensions or alpha precision")
    offsets = struct.unpack_from("<16I", data, 20)
    sizes = struct.unpack_from("<16I", data, 84)
    levels = []
    for level, (offset, size) in enumerate(zip(offsets, sizes)):
        if not size:
            if any(sizes[level:]):
                raise ValueError("Noncontiguous BLP mip levels")
            break
        count = max(1, width >> level) * max(1, height >> level)
        required = count * 4 if data[8] == 3 else count + (count * data[9] + 7) // 8
        if offset < 1172 or size < required or offset + size > len(data):
            raise ValueError("Invalid BLP pixel span")
        if data[8] == 3:
            levels.append(data[offset:offset + count * 4])
            continue
        pixels = bytearray(count * 4)
        for index in range(count):
            color = 148 + data[offset + index] * 4
            if data[9] == 0:
                alpha = 255
            elif data[9] == 8:
                alpha = data[offset + count + index]
            else:
                bit = index * data[9]
                value = (data[offset + count + bit // 8] >> (bit % 8)) & ((1 << data[9]) - 1)
                alpha = value * (255 // ((1 << data[9]) - 1))
            pixels[index * 4:index * 4 + 4] = data[color:color + 3] + bytes((alpha,))
        levels.append(bytes(pixels))
    if not levels:
        raise ValueError("Missing BLP base level")
    return width, height, levels


def image_from_bytes(data):
    """Decode authoring inputs with exact Raw1/Raw3 alpha and a Pillow fallback."""
    from PIL import Image

    if len(data) >= 9 and data[:4] == b"BLP2" and data[8] in (1, 3):
        width, height, levels = blp_bgra_levels(data)
        return Image.frombytes("RGBA", (width, height), levels[0], "raw", "BGRA")
    return Image.open(io.BytesIO(data)).convert("RGBA")


def lossless_palette(data):
    """Use Raw1 only when one exact RGB palette fits every existing mip level.

    Wenilla reads RGB from the BGRA palette and alpha from a separate 0/1/8-bit
    block. Do not quantize colors, alpha or transparent pixels. The decoder and
    byte layout are pinned in docs/CLIENT-COMPATIBILITY.md.
    """
    if len(data) < 1172 or data[:4] != b"BLP2" or data[8] != 3:
        return data
    width, height, levels = blp_bgra_levels(data)
    colors = {}
    for pixels in levels:
        for position in range(0, len(pixels), 4):
            color = pixels[position:position + 3]
            if color not in colors:
                if len(colors) == 256:
                    return data
                colors[color] = len(colors)
    alpha = b"".join(pixels[3::4] for pixels in levels)
    if all(value == 255 for value in alpha):
        alpha_bits = 0
    elif all(value in (0, 255) for value in alpha):
        alpha_bits = 1
    else:
        alpha_bits = 8
    header = bytearray(data[:148]) + bytearray(1024)
    header[8:11] = bytes((1, alpha_bits, 0))
    header[20:148] = bytes(128)
    for color, index in colors.items():
        header[148 + index * 4:152 + index * 4] = color + b"\xff"

    body = bytearray()
    for level, pixels in enumerate(levels):
        indices = bytes(colors[pixels[position:position + 3]] for position in range(0, len(pixels), 4))
        alpha = pixels[3::4]
        if alpha_bits == 0:
            packed = b""
        elif alpha_bits == 8:
            packed = alpha
        else:
            packed = bytearray((len(alpha) + 7) // 8)
            for position, value in enumerate(alpha):
                if value:
                    packed[position // 8] |= 1 << (position % 8)
        payload = indices + packed
        struct.pack_into("<I", header, 20 + level * 4, len(header) + len(body))
        struct.pack_into("<I", header, 84 + level * 4, len(payload))
        body.extend(payload)
    converted = bytes(header + body)
    if len(converted) >= len(data):
        return data
    if blp_bgra_levels(converted) != (width, height, levels):
        raise ValueError("Palette conversion changed pixels, alpha or mip levels")
    return converted


def blp_from_bgra(width, height, pixels):
    """Wrap top-down BGRA8 pixels in a Raw3 intermediate, without resampling."""
    size = width * height * 4
    if len(pixels) != size:
        raise ValueError("BGRA pixel span does not match its dimensions")
    # Native BLP2 Raw3 requires a palette block, even though it does not use it.
    header = bytearray(148 + 256 * 4)
    struct.pack_into("<4sI4BII", header, 0, b"BLP2", 1, 3, 8, 0, 0, width, height)
    struct.pack_into("<I", header, 20, len(header))
    struct.pack_into("<I", header, 84, size)
    return bytes(header) + pixels


def blp_from_tga(data):
    """Keep the canvas and every BGRA pixel, changing only its file container."""
    if len(data) < 18 or data[1] != 0 or data[2] not in (2, 10) or data[16] not in (24, 32):
        raise ValueError("Expected a raw or RLE 24/32-bit truecolour TGA")
    width, height = struct.unpack_from("<HH", data, 12)
    offset = 18 + data[0]
    stride = data[16] // 8
    size = width * height * stride
    if data[2] == 2:
        pixels = data[offset:offset + size]
        if len(pixels) != size:
            raise ValueError("Truncated TGA pixel data")
    else:
        pixels = bytearray()
        while len(pixels) < size:
            if offset >= len(data):
                raise ValueError("Truncated TGA RLE packet")
            packet = data[offset]
            offset += 1
            count = (packet & 0x7F) + 1
            span = stride if packet & 0x80 else count * stride
            chunk = data[offset:offset + span]
            if len(chunk) != span or len(pixels) + count * stride > size:
                raise ValueError("Invalid TGA RLE pixel span")
            pixels.extend(chunk * count if packet & 0x80 else chunk)
            offset += span
        pixels = bytes(pixels)
    if stride == 3:
        opaque = bytearray(width * height * 4)
        for index in range(width * height):
            opaque[index * 4:index * 4 + 4] = pixels[index * 3:index * 3 + 3] + b"\xff"
        pixels = bytes(opaque)
    if data[17] & 0x10:
        raise ValueError("Right-origin TGA artwork needs an explicit conversion")
    if not data[17] & 0x20:
        row = width * 4
        pixels = b"".join(pixels[y * row:(y + 1) * row] for y in range(height - 1, -1, -1))

    return blp_from_bgra(width, height, pixels), {
        "width": width,
        "height": height,
        "bgra_sha256": hashlib.sha256(pixels).hexdigest(),
    }


def prepare_health_fill():
    """Fit the authored interior to a legal native StatusBar texture canvas."""
    source = ROOT / "media/tex/unitframes/healthDF2.tga"
    destination = ROOT / "media/tex/unitframes/healthDF2Fill.blp"
    converted, record = blp_from_tga(source.read_bytes())
    if (record["width"], record["height"]) != (128, 32):
        raise ValueError("The health atlas changed; review its authored crop first")
    offset = struct.unpack_from("<I", converted, 20)[0]
    pixels = converted[offset:]
    # These columns enclose the existing 6.5..121.5 sampling window;
    # the same twenty interior rows were sampled from y=5 through y=25.
    left, top, right, bottom = 6, 5, 122, 25
    width, height = right - left, bottom - top
    cropped = b"".join(pixels[(y * 128 + left) * 4:(y * 128 + right) * 4]
                       for y in range(top, bottom))
    from PIL import Image

    # StatusBar owns full-range UVs, so transparent padding would change its
    # shape and health fraction. Resample this interior once during authoring;
    # all runtime consumers keep the same native geometry and 0..1 coordinates.
    image = Image.frombytes("RGBA", (width, height), cropped, "raw", "BGRA")
    image = image.resize((128, 32), Image.Resampling.LANCZOS)
    save_image(image, destination)
    return {"source": source.relative_to(ROOT).as_posix(),
            "destination": destination.relative_to(ROOT).as_posix(),
            "source_crop": [left, top, right, bottom],
            "width": 128, "height": 32,
            "bgra_sha256": hashlib.sha256(image.tobytes("raw", "BGRA")).hexdigest()}


def tally_canvas(path):
    """Reassemble the referenced 600-pixel tally span for artwork generators."""
    from PIL import Image

    image = image_from_bytes(path.read_bytes())
    if image.width != 512:
        return image
    right = image_from_bytes(path.with_stem(path.stem + "_2").read_bytes())
    canvas = Image.new("RGBA", (1024, 128))
    canvas.paste(image.crop((1, 0, 301, 128)), (0, 0))
    canvas.paste(right.crop((1, 0, 301, 128)), (300, 0))
    return canvas


def prepare_runtime_dimensions():
    """Repack wide sheets into power-of-two BLPs between 8 and 512 pixels.

    Atlas cells retain their pixels. Wide strips keep a neighbour gutter on
    either side of each join, and render side by side at the original size.
    Already prepared sheets are left alone; regenerated originals are repacked.
    """
    from PIL import Image

    manifest_path = ROOT / "packaging/runtime-files.json"
    manifest = json.loads(manifest_path.read_text())
    added, records = {}, []
    for name in list(manifest["files"]):
        if not name.endswith(".blp"):
            continue
        path = ROOT / name
        data = path.read_bytes()
        width, height = struct.unpack_from("<II", data, 12)
        if 8 <= width <= 512 and 8 <= height <= 512 and not (width & (width - 1) or height & (height - 1)):
            continue
        source = image_from_bytes(data)
        outputs = []
        if name == "media/tex/character/Chrome.blp" and source.size == (1024, 256):
            atlas = Image.new("RGBA", (512, 512))
            atlas.paste(source.crop((0, 0, 512, 256)), (0, 0))
            atlas.paste(source.crop((512, 0, 1024, 256)), (0, 256))
            outputs.append((path, atlas))
        elif name == "media/tex/jewelry/Frame.blp" and source.size == (1024, 256):
            atlas = Image.new("RGBA", (512, 128))
            for index, left in enumerate((106, 576, 664)):
                atlas.paste(source.crop((left - 1, 55, left + 73, 129)), (index * 128, 0))
            outputs.append((path, atlas))
        else:
            if name == "media/tex/jewelry/SocketRail.blp":
                count, span = 3, 400
            elif name == "media/tex/guardians/Header.blp":
                count, span = 2, 280
            elif name == "media/tex/editor/divider.blp":
                count, span = 2, 315
            elif path.parent.name == "tally" and source.size == (1024, 128):
                count, span = 2, 300
            else:
                raise ValueError("Artwork needs an explicit size-compatible recipe: " + name)
            if source.height == 1:
                # The divider's sole row is repeated exactly, not filtered.
                row = source
                source = Image.new("RGBA", (source.width, 8))
                for y in range(8):
                    source.paste(row, (0, y))
            for index in range(count):
                left = index * span
                tile = Image.new("RGBA", (512, source.height))
                tile.paste(source.crop((left, 0, left + span, source.height)), (1, 0))
                neighbour = max(0, left - 1)
                tile.paste(source.crop((neighbour, 0, neighbour + 1, source.height)), (0, 0))
                tile.paste(source.crop((left + span, 0, left + span + 1, source.height)), (span + 1, 0))
                output = path if index == 0 else path.with_stem(path.stem + "_" + str(index + 1))
                outputs.append((output, tile))
        for output, image in outputs:
            save_image(image, output)
            relative = output.relative_to(ROOT).as_posix()
            if relative not in manifest["files"]:
                added.setdefault(name, []).append(relative)
            records.append({"file": relative, "width": image.width, "height": image.height})
    if added:
        manifest["files"] = [output for name in manifest["files"] for output in [name, *added.get(name, [])]]
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    return records


def save_image(image, path):
    """Let existing artwork generators write the same lossless BLP container."""
    if path.suffix.lower() == ".blp":
        temporary = io.BytesIO()
        image.convert("RGBA").save(temporary, format="TGA", compression=None)
        converted, _ = blp_from_tga(temporary.getvalue())
        path.write_bytes(lossless_palette(converted))
    else:
        image.save(path, compression=None)


def prepare():
    manifest = json.loads((ROOT / "packaging/runtime-files.json").read_text())
    pending = []
    for name in manifest["files"]:
        destination = ROOT / name
        if destination.suffix.lower() == ".tga":
            raise ValueError("Runtime artwork must name its prepared BLP: " + name)
        if destination.suffix.lower() != ".blp":
            continue
        source_name = TGA_SOURCES.get(name, str(Path(name).with_suffix(".tga")))
        if source_name is None:
            continue
        source = ROOT / source_name
        if not source.is_file():
            continue
        data = source.read_bytes()
        converted, record = blp_from_tga(data)
        record.update({"source": source.relative_to(ROOT).as_posix(), "destination": name})
        pending.append((destination, converted, record))

    records = []
    for destination, converted, record in pending:
        destination.write_bytes(converted)
        records.append(record)

    # The tally generator writes filenames into this registry alongside its
    # TGA inputs. Keep that generated metadata aligned after repacking.
    registry = ROOT / "core/tally.lua"
    text = registry.read_text()
    for record in records:
        if Path(record["source"]).parent == Path("media/tex/tally"):
            text = text.replace('"' + Path(record["source"]).name + '"',
                                '"' + Path(record["destination"]).name + '"')
    registry.write_text(text)

    health_fill = prepare_health_fill()
    palettes = []
    for name in manifest["files"]:
        if not name.endswith(".blp"):
            continue
        destination = ROOT / name
        original = destination.read_bytes()
        converted = lossless_palette(original)
        if converted == original:
            continue
        destination.write_bytes(converted)
        width, height = struct.unpack_from("<II", original, 12)
        offset = struct.unpack_from("<I", original, 20)[0]
        palettes.append({"destination": name, "width": width, "height": height,
                         "alpha_bits": converted[9], "before_bytes": len(original),
                         "after_bytes": len(converted),
                         "bgra_sha256": hashlib.sha256(original[offset:offset + width * height * 4]).hexdigest()})
    dimensions = prepare_runtime_dimensions()
    return {"converted": records, "health_fill": health_fill, "palettes": palettes, "dimensions": dimensions}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--runtime-dimensions-only", action="store_true",
                        help="Repack existing runtime artwork and the health interior only")
    args = parser.parse_args()
    if args.runtime_dimensions_only:
        receipt = {"converted": [], "health_fill": prepare_health_fill(), "palettes": [],
                   "dimensions": prepare_runtime_dimensions()}
    else:
        receipt = prepare()
    if args.receipt:
        args.receipt.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"converted_files": len(receipt["converted"]),
                      "health_fill": receipt["health_fill"],
                      "palette_files": len(receipt["palettes"]),
                      "palette_saved_bytes": sum(row["before_bytes"] - row["after_bytes"] for row in receipt["palettes"]),
                      "dimension_outputs": len(receipt["dimensions"])}))
