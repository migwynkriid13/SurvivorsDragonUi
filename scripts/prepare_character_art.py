"""Extract the pinned Blizzard character-panel pixels; never execute addon code."""

import io
import pathlib
import struct
import urllib.request

from PIL import Image


ROOT = pathlib.Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "media/tex/character"
DRAGONUI = "https://raw.githubusercontent.com/NeticSoul/DragonUI/6d9cc95eedd1de78fab3b965683df13421e21604/DragonUI/Textures/"
DRAGONFLIGHT = "https://raw.githubusercontent.com/Gethe/wow-ui-textures/e80e3278cc833c89e1f3fc79557b68315d750935/"


def source(base, path):
    with urllib.request.urlopen(base + path, timeout=60) as response:
        data = response.read()
    if data[:4] == b"BLP2" and data[8] == 3:
        width, height = struct.unpack_from("<II", data, 12)
        offset = struct.unpack_from("<I", data, 20)[0]
        return Image.frombytes(
            "RGBA", (width, height), data[offset : offset + width * height * 4], "raw", "BGRA"
        )
    return Image.open(io.BytesIO(data)).convert("RGBA")


def save(image, name):
    DESTINATION.mkdir(parents=True, exist_ok=True)
    image.save(DESTINATION / name, compression=None)


def prepare():
    metal = source(DRAGONUI, "UI/uiframemetal2x.blp")
    horizontal = source(DRAGONUI, "UI/uiframemetalhorizontal2x.blp")
    vertical = source(DRAGONUI, "UI/uiframemetalvertical2x.blp")
    chrome = Image.new("RGBA", (1024, 256))
    for sheet, rectangle, destination in [
        (metal, (1, 1, 151, 151), (0, 0)),
        (metal, (153, 1, 303, 151), (256, 0)),
        (metal, (153, 153, 217, 217), (512, 0)),
        (metal, (219, 153, 283, 217), (640, 0)),
        (horizontal, (0, 1, 64, 151), (768, 0)),
        (horizontal, (0, 153, 32, 217), (896, 0)),
        (vertical, (1, 0, 151, 32), (0, 192)),
        (vertical, (153, 0, 303, 32), (256, 192)),
    ]:
        chrome.paste(sheet.crop(rectangle), destination)
    save(chrome, "Chrome.tga")

    parts = Image.new("RGBA", (256, 256))
    parts.paste(source(DRAGONFLIGHT, "CHARACTERFRAME/Char-Paperdoll-Parts.PNG"), (0, 0))
    parts.paste(source(DRAGONFLIGHT, "CHARACTERFRAME/Char-Paperdoll-Horizontal.PNG"), (0, 128))
    parts.paste(source(DRAGONFLIGHT, "CHARACTERFRAME/Char-Paperdoll-Vertical.PNG"), (64, 128))
    parts.paste(source(DRAGONUI, "CharacterPanel/charstatmiddle.blp"), (0, 192))
    save(parts, "Parts.tga")
    save(source(DRAGONFLIGHT, "COMMON/WhiteIconFrame.PNG"), "QualityBorder.tga")

    background = Image.new("RGBA", (512, 512))
    background.paste(
        source(DRAGONUI, "CharacterPanel/characterpanelbackground.blp").crop((1, 1, 451, 421)), (0, 0)
    )
    save(background, "Background.tga")
    save(source(DRAGONUI, "UI/uiframetabs.blp"), "Tabs.tga")

    buttons = source(DRAGONUI, "UI/redbutton2x.blp")
    close = Image.new("RGBA", (128, 128))
    for rectangle, destination in [
        ((39, 1, 75, 39), (0, 0)),
        ((39, 81, 75, 119), (64, 0)),
        ((39, 41, 75, 79), (0, 64)),
        ((115, 1, 151, 39), (64, 64)),
    ]:
        close.paste(buttons.crop(rectangle), destination)
    save(close, "Close.tga")


if __name__ == "__main__":
    prepare()
